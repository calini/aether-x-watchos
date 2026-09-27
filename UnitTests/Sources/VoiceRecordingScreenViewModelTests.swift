//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementXWatch
import Foundation
import Testing

struct VoiceRecordingScreenViewModelTests {
    @Test
    func appearStartsRecording() async throws {
        let harness = Harness()
        #expect(harness.viewState.step == .starting)

        harness.send(.appear)
        harness.send(.appear)

        try await waitUntil { harness.viewState.step == .recording(elapsed: 0, level: 0, isNearLimit: false) }
        #expect(harness.recorder.startCallsCount == 1)

        harness.recorderState.send(.recording(elapsed: 271, level: 0.5, isNearLimit: true))
        #expect(harness.viewState.step == .recording(elapsed: 271, level: 0.5, isNearLimit: true))
    }

    @Test
    func deniedPermissionShowsExplanation() async throws {
        let harness = Harness()
        harness.recorder.startClosure = { .failure(.permissionDenied) }

        harness.send(.appear)

        try await waitUntil { harness.viewState.step == .permissionDenied }
        #expect(harness.viewState.bindings.errorMessage == nil)
        #expect(harness.actions.isEmpty)
    }

    @Test
    func startFailureShowsErrorAndFinishes() async throws {
        let harness = Harness()
        harness.recorder.startClosure = { .failure(.failed) }

        harness.send(.appear)

        try await waitUntil { harness.viewState.bindings.errorMessage == WatchStrings.recordVoiceMessageFailed }
        #expect(!harness.viewState.bindings.canRetrySend)

        harness.send(.delete)
        #expect(harness.actions == [.cancelled])
    }

    @Test
    func stopPreparesThenReviews() async throws {
        let harness = try await Harness.recording()
        let gate = AsyncGate()
        harness.encodeGate = gate

        harness.send(.stop)

        #expect(harness.recorder.stopCallsCount == 1)
        #expect(harness.viewState.step == .preparing)
        try await waitUntil { harness.encodedURLs == [harness.pcmURL] }

        await gate.open()
        try await waitUntil { harness.viewState.step == .review(harness.encoded, waveform: Harness.waveform) }
        #expect(harness.actions.isEmpty)
        #expect(harness.filesExist)
    }

    @Test
    func recorderAutoStopReviews() async throws {
        let harness = try await Harness.recording()

        harness.recorderState.send(.stopped(harness.recording))

        try await waitUntil { harness.viewState.step == .review(harness.encoded, waveform: Harness.waveform) }
        #expect(harness.recorder.stopCallsCount == 0)
        #expect(harness.encodedURLs == [harness.pcmURL])
    }

    @Test
    func shortRecordingFinishes() async throws {
        let harness = try await Harness.recording()

        harness.recorderState.send(.discarded)

        #expect(harness.actions == [.cancelled])
        #expect(harness.encodedURLs.isEmpty)
    }

    @Test
    func encodeFailureShowsErrorAndFinishes() async throws {
        let harness = try await Harness.recording()
        harness.encodeResult = .failure(.encodingFailed)

        harness.send(.stop)

        try await waitUntil { harness.viewState.bindings.errorMessage == WatchStrings.prepareVoiceMessageFailed }
        #expect(!harness.viewState.bindings.canRetrySend)
        #expect(!FileManager.default.fileExists(atPath: harness.pcmURL.path()))
        #expect(harness.recorder.cancelCallsCount == 0)
        #expect(harness.actions.isEmpty)

        harness.send(.delete)
        #expect(harness.actions == [.cancelled])
    }

    @Test
    func togglePlaybackPlaysAndPauses() async throws {
        let harness = try await Harness.reviewing()

        harness.send(.togglePlayback)
        try await waitUntil { harness.player.playFileURLReceivedFileURL == harness.oggURL }
        harness.playerState.send(.playing(progress: 0.25))
        #expect(harness.viewState.isPlaying)
        #expect(harness.viewState.playbackProgress == 0.25)
        #expect(harness.viewState.remainingPlaybackTime == 3)

        harness.send(.togglePlayback)
        #expect(harness.player.pauseCallsCount == 1)
        harness.playerState.send(.paused(progress: 0.25))
        #expect(!harness.viewState.isPlaying)
        #expect(harness.viewState.playbackProgress == 0.25)

        harness.playerState.send(.stopped)
        #expect(harness.viewState.playbackProgress == 0)
        #expect(harness.player.playFileURLCallsCount == 1)
    }

    @Test
    func doubleTapPlayStartsPlaybackOnce() async throws {
        let harness = try await Harness.reviewing()
        let gate = AsyncGate()
        harness.player.playFileURLClosure = { _ in
            await gate.wait()
            return .success(())
        }

        harness.send(.togglePlayback)
        harness.send(.togglePlayback)
        await gate.open()
        try await Task.sleep(for: .milliseconds(50))

        #expect(harness.player.playFileURLCallsCount == 1)
        #expect(harness.player.pauseCallsCount == 0)
    }

    @Test
    func sendSucceedsAndFinishes() async throws {
        let harness = try await Harness.reviewing()
        let gate = AsyncGate()
        harness.sendGate = gate

        harness.send(.send)

        #expect(harness.viewState.step == .sending)
        #expect(harness.player.stopCalled)
        try await waitUntil { harness.sent.count == 1 }
        #expect(harness.sent.first?.message == harness.encoded)
        #expect(harness.sent.first?.waveform == Harness.waveform)
        #expect(harness.filesExist)

        await gate.open()
        try await waitUntil { harness.actions == [.done] }
        #expect(harness.viewState.step == .sending)
        #expect(harness.noFilesExist)
        #expect(harness.recorder.cancelCallsCount == 0)
    }

    @Test
    func sendFailureOffersRetry() async throws {
        let harness = try await Harness.reviewing()
        harness.sendResults = [.failure(.sdkError("offline")), .success(())]

        harness.send(.send)

        try await waitUntil { harness.viewState.bindings.errorMessage == WatchStrings.sendVoiceMessageFailed }
        #expect(harness.viewState.bindings.canRetrySend)
        #expect(harness.viewState.step == .review(harness.encoded, waveform: Harness.waveform))
        #expect(harness.filesExist)
        #expect(harness.actions.isEmpty)

        harness.send(.retrySend)

        try await waitUntil { harness.actions == [.done] }
        #expect(harness.sent.count == 2)
        #expect(harness.noFilesExist)
    }

    @Test
    func doubleTapSendSendsOnce() async throws {
        let harness = try await Harness.reviewing()
        let gate = AsyncGate()
        harness.sendGate = gate

        harness.send(.send)
        harness.send(.send)
        await gate.open()
        try await waitUntil { harness.actions == [.done] }
        harness.send(.send)
        harness.send(.retrySend)

        #expect(harness.sent.count == 1)
        #expect(harness.actions == [.done])
    }

    @Test
    func deleteDiscards() async throws {
        let harness = try await Harness.reviewing()

        harness.send(.delete)

        #expect(harness.actions == [.cancelled])
        #expect(harness.noFilesExist)
        #expect(harness.player.stopCalled)
        #expect(harness.recorder.cancelCallsCount == 0)
        harness.send(.send)
        #expect(harness.sent.isEmpty)
    }

    @Test
    func dismissalDiscards() async throws {
        let harness = try await Harness.reviewing()

        harness.send(.dismiss)

        #expect(harness.noFilesExist)
        #expect(harness.player.stopCalled)
        #expect(harness.recorder.cancelCallsCount == 0)
        harness.send(.send)
        #expect(harness.sent.isEmpty)
    }

    @Test
    func dismissalWhileRecordingCancelsTheRecorder() async throws {
        let harness = try await Harness.recording()

        harness.send(.dismiss)

        #expect(harness.recorder.cancelCallsCount == 1)
        #expect(!FileManager.default.fileExists(atPath: harness.pcmURL.path()))
        harness.send(.stop)
        #expect(harness.recorder.stopCallsCount == 0)
    }

    @Test
    func dismissalDuringThePermissionPromptCancelsTheRecorder() async throws {
        let harness = Harness()
        let gate = AsyncGate()
        harness.recorder.startClosure = {
            await gate.wait()
            return .failure(.failed)
        }
        harness.send(.appear)
        try await waitUntil { harness.recorder.startCalled }

        harness.send(.dismiss)
        await gate.open()

        #expect(harness.recorder.cancelCallsCount == 1)
        try await Task.sleep(for: .milliseconds(50))
        #expect(harness.viewState.bindings.errorMessage == nil)
    }

    @Test
    func dismissalWhilePreparingDeletesTheFilesOnceEncoded() async throws {
        let harness = try await Harness.recording()
        let gate = AsyncGate()
        harness.encodeGate = gate
        harness.send(.stop)
        try await waitUntil { !harness.encodedURLs.isEmpty }

        harness.send(.dismiss)
        #expect(harness.recorder.cancelCallsCount == 0)
        #expect(FileManager.default.fileExists(atPath: harness.pcmURL.path()))

        await gate.open()
        try await waitUntil { harness.noFilesExist }
        #expect(harness.viewState.step == .preparing)
        #expect(harness.sent.isEmpty)
    }

    @Test
    func dismissalWhileSendingDeletesTheFilesOnceSent() async throws {
        let harness = try await Harness.reviewing()
        let gate = AsyncGate()
        harness.sendGate = gate
        harness.sendResults = [.failure(.sdkError("offline"))]
        harness.send(.send)
        try await waitUntil { harness.sent.count == 1 }

        harness.send(.dismiss)
        #expect(harness.filesExist)

        await gate.open()
        try await waitUntil { harness.noFilesExist }
        #expect(harness.viewState.bindings.errorMessage == nil)
        harness.send(.retrySend)
        #expect(harness.sent.count == 1)
    }
}

// MARK: - Helpers

@MainActor
private final class Harness {
    static let waveform: [Float] = [0.1, 0.5, 1]

    let recorderState = CurrentValueSubject<VoiceRecorderState, Never>(.idle)
    let recorder = VoiceMessageRecorderMock()
    let playerState = CurrentValueSubject<VoiceMessagePreviewPlayerState, Never>(.stopped)
    let player = VoiceMessagePreviewPlayerMock()
    let pcmURL: URL
    let oggURL: URL
    var encodeGate: AsyncGate?
    var encodeResult: Result<Void, OpusCodecError> = .success(())
    private(set) var encodedURLs: [URL] = []
    var sendGate: AsyncGate?
    var sendResults: [Result<Void, TimelineProxyError>] = []
    private(set) var sent: [(message: EncodedVoiceMessage, waveform: [Float])] = []
    private(set) var actions: [VoiceRecordingScreenViewModelAction] = []
    private var viewModel: VoiceRecordingScreenViewModel!
    private var cancellable: AnyCancellable?

    var recording: RecordedVoiceMessage {
        RecordedVoiceMessage(pcmURL: pcmURL, duration: 4, waveform: Self.waveform)
    }

    var encoded: EncodedVoiceMessage {
        EncodedVoiceMessage(fileURL: oggURL, duration: 4, size: 3)
    }

    var viewState: VoiceRecordingScreenViewState {
        viewModel.context.viewState
    }

    var filesExist: Bool {
        FileManager.default.fileExists(atPath: pcmURL.path()) && FileManager.default.fileExists(atPath: oggURL.path())
    }

    var noFilesExist: Bool {
        !FileManager.default.fileExists(atPath: pcmURL.path()) && !FileManager.default.fileExists(atPath: oggURL.path())
    }

    init() {
        let name = UUID().uuidString
        pcmURL = FileManager.default.temporaryDirectory.appending(path: "\(name).caf")
        oggURL = FileManager.default.temporaryDirectory.appending(path: "\(name).ogg")

        recorder.statePublisher = recorderState.eraseToAnyPublisher()
        recorder.startClosure = { [recorderState, pcmURL] in
            FileManager.default.createFile(atPath: pcmURL.path(), contents: Data([1]))
            recorderState.send(.recording(elapsed: 0, level: 0, isNearLimit: false))
            return .success(())
        }
        recorder.stopClosure = { [recorderState, recording] in recorderState.send(.stopped(recording)) }
        recorder.cancelClosure = { [recorderState, pcmURL] in
            try? FileManager.default.removeItem(at: pcmURL)
            recorderState.send(.idle)
        }
        player.statePublisher = playerState.eraseToAnyPublisher()
        player.playFileURLReturnValue = .success(())

        viewModel = VoiceRecordingScreenViewModel(recorder: recorder,
                                                  encode: { [weak self] url in await self?.encode(url) ?? .failure(.encodingFailed) },
                                                  send: { [weak self] message, waveform in
                                                      await self?.sendMessage(message, waveform: waveform) ?? .failure(.sdkError("gone"))
                                                  },
                                                  previewPlayer: player)
        cancellable = viewModel.actionsPublisher.sink { [weak self] in self?.actions.append($0) }
    }

    deinit {
        try? FileManager.default.removeItem(at: pcmURL)
        try? FileManager.default.removeItem(at: oggURL)
    }

    static func recording() async throws -> Harness {
        let harness = Harness()
        harness.send(.appear)
        try await waitUntil { harness.viewState.step == .recording(elapsed: 0, level: 0, isNearLimit: false) }
        return harness
    }

    static func reviewing() async throws -> Harness {
        let harness = try await recording()
        harness.send(.stop)
        try await waitUntil { harness.viewState.step == .review(harness.encoded, waveform: waveform) }
        return harness
    }

    func send(_ action: VoiceRecordingScreenViewAction) {
        viewModel.context.send(viewAction: action)
    }

    private func encode(_ url: URL) async -> Result<EncodedVoiceMessage, OpusCodecError> {
        encodedURLs.append(url)
        await encodeGate?.wait()
        switch encodeResult {
        case .success:
            FileManager.default.createFile(atPath: oggURL.path(), contents: Data([1, 2, 3]))
            return .success(encoded)
        case .failure(let error):
            return .failure(error)
        }
    }

    private func sendMessage(_ message: EncodedVoiceMessage, waveform: [Float]) async -> Result<Void, TimelineProxyError> {
        sent.append((message, waveform))
        await sendGate?.wait()
        return sendResults.isEmpty ? .success(()) : sendResults.removeFirst()
    }
}
