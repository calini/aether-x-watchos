//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation

typealias VoiceRecordingScreenViewModelType = StateStoreViewModelV2<VoiceRecordingScreenViewState, VoiceRecordingScreenViewAction>

final class VoiceRecordingScreenViewModel: VoiceRecordingScreenViewModelType, VoiceRecordingScreenViewModelProtocol {
    private let recorder: VoiceMessageRecorderProtocol
    private let encode: (URL) async -> Result<EncodedVoiceMessage, OpusCodecError>
    private let sendMessage: (EncodedVoiceMessage, [Float]) async -> Result<Void, TimelineProxyError>
    private let previewPlayer: VoiceMessagePreviewPlayerProtocol
    private let actionsSubject = PassthroughSubject<VoiceRecordingScreenViewModelAction, Never>()
    private var hasAppeared = false
    /// Sent, discarded or dismissed: nothing new starts, and the files go as soon as nothing uses them.
    private var isFinished = false
    /// The recording the recorder handed over: its files are ours to delete from then on.
    private var recording: RecordedVoiceMessage?
    private var encoded: EncodedVoiceMessage?
    /// The encoder or the SDK is reading the files, so they can't be deleted yet.
    private var areFilesInUse = false
    /// The first play decodes the file, so a second tap meanwhile mustn't start another.
    private var isStartingPlayback = false

    var actionsPublisher: AnyPublisher<VoiceRecordingScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    /// - Parameter encode: Turns the recorded PCM file into Ogg Opus, off the main actor.
    init(recorder: VoiceMessageRecorderProtocol,
         encode: @escaping (URL) async -> Result<EncodedVoiceMessage, OpusCodecError>,
         send: @escaping (EncodedVoiceMessage, [Float]) async -> Result<Void, TimelineProxyError>,
         previewPlayer: VoiceMessagePreviewPlayerProtocol) {
        self.recorder = recorder
        self.encode = encode
        sendMessage = send
        self.previewPlayer = previewPlayer
        super.init(initialViewState: VoiceRecordingScreenViewState())

        recorder.statePublisher
            .sink { [weak self] recorderState in self?.handleRecorderState(recorderState) }
            .store(in: &cancellables)
        previewPlayer.statePublisher
            .sink { [weak self] playerState in self?.handlePlayerState(playerState) }
            .store(in: &cancellables)
    }

    override func process(viewAction: VoiceRecordingScreenViewAction) {
        guard !isFinished else { return }
        switch viewAction {
        case .appear:
            guard !hasAppeared else { return }
            hasAppeared = true
            startRecording()
        case .stop:
            // The recorder ignores a stop before it's recording, so Stop is only offered while recording.
            guard case .recording = state.step else { return }
            recorder.stop()
        case .togglePlayback:
            togglePlayback()
        case .send, .retrySend:
            send()
        case .delete:
            discard()
            actionsSubject.send(.cancelled)
        case .dismiss:
            discard()
        }
    }

    // MARK: - Private

    private func startRecording() {
        Task {
            let result = await recorder.start()
            guard !isFinished else { return }
            switch result {
            case .success:
                break // The recorder's state follows.
            case .failure(.permissionDenied):
                state.step = .permissionDenied
            case .failure(.failed):
                showError(WatchStrings.recordVoiceMessageFailed)
            }
        }
    }

    private func handleRecorderState(_ recorderState: VoiceRecorderState) {
        guard !isFinished else { return }
        switch recorderState {
        case let .recording(elapsed, level, isNearLimit):
            switch state.step {
            case .starting, .recording: state.step = .recording(elapsed: elapsed, level: level, isNearLimit: isNearLimit)
            default: break
            }
        case .stopped(let message):
            guard recording == nil else { return }
            recording = message
            prepare(message)
        case .discarded:
            isFinished = true
            actionsSubject.send(.cancelled)
        case .idle, .failed:
            break
        }
    }

    private func prepare(_ message: RecordedVoiceMessage) {
        state.step = .preparing
        areFilesInUse = true
        Task {
            let result = await encode(message.pcmURL)
            areFilesInUse = false
            if case .success(let encoded) = result {
                self.encoded = encoded
            }
            guard !isFinished else {
                deleteFiles()
                return
            }
            switch result {
            case .success(let encoded):
                state.step = .review(encoded, waveform: message.waveform)
            case .failure:
                MXLog.error("Preparing the voice message failed")
                deleteFiles()
                showError(WatchStrings.prepareVoiceMessageFailed)
            }
        }
    }

    private func handlePlayerState(_ playerState: VoiceMessagePreviewPlayerState) {
        switch playerState {
        case .stopped:
            state.isPlaying = false
            state.playbackProgress = 0
        case .playing(let progress):
            state.isPlaying = true
            state.playbackProgress = progress
        case .paused(let progress):
            state.isPlaying = false
            state.playbackProgress = progress
        }
    }

    private func togglePlayback() {
        guard case let .review(message, _) = state.step else { return }
        guard !state.isPlaying else {
            previewPlayer.pause()
            return
        }
        guard !isStartingPlayback else { return }
        isStartingPlayback = true
        Task {
            let result = await previewPlayer.play(fileURL: message.fileURL)
            isStartingPlayback = false
            if case .failure = result, !isFinished {
                MXLog.error("Playing the voice message preview failed")
            }
        }
    }

    private func send() {
        guard case let .review(message, waveform) = state.step else { return }
        previewPlayer.stop()
        state.step = .sending
        areFilesInUse = true
        Task {
            let result = await sendMessage(message, waveform)
            areFilesInUse = false
            guard !isFinished else {
                deleteFiles()
                return
            }
            switch result {
            case .success:
                // Stays on `.sending`: Send mustn't come back while the sheet closes, or a second tap sends again.
                isFinished = true
                deleteFiles()
                actionsSubject.send(.done)
            case .failure:
                state.step = .review(message, waveform: waveform)
                showError(WatchStrings.sendVoiceMessageFailed, canRetrySend: true)
            }
        }
    }

    private func discard() {
        isFinished = true
        previewPlayer.stop()
        if recording == nil {
            // Still the recorder's: it stops if needed and deletes its file.
            recorder.cancel()
        } else if !areFilesInUse {
            deleteFiles()
        }
    }

    private func deleteFiles() {
        let urls = [recording?.pcmURL, encoded?.fileURL].compactMap(\.self)
        urls.forEach { try? FileManager.default.removeItem(at: $0) }
    }

    private func showError(_ message: String, canRetrySend: Bool = false) {
        state.bindings.canRetrySend = canRetrySend
        state.bindings.errorMessage = message
    }
}
