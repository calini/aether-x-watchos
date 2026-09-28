//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Combine

enum VoiceMessagePreviewPlayerState: Equatable {
    case stopped
    /// `progress` is in 0…1.
    case playing(progress: Double)
    case paused(progress: Double)
}

enum VoiceMessagePreviewPlayerError: Error {
    case failed
}

// sourcery: AutoMockable
/// Plays back a voice message before it's sent.
protocol VoiceMessagePreviewPlayerProtocol: AnyObject {
    var statePublisher: AnyPublisher<VoiceMessagePreviewPlayerState, Never> { get }

    /// Decodes the Ogg Opus file on first use, then plays it or resumes it.
    func play(fileURL: URL) async -> Result<Void, VoiceMessagePreviewPlayerError>
    func pause()
    /// Stops, releases the audio session and deletes the decoded copy.
    func stop()
}

final class VoiceMessagePreviewPlayer: VoiceMessagePreviewPlayerProtocol {
    private static let progressInterval = Duration.milliseconds(100)

    private let audioSession: AudioSessionProxyProtocol
    private let makeAudioPlayer: (URL) throws -> AudioPlaybackBackend
    private let makeTickSleeper: () -> @Sendable (Int) async throws -> Void
    private let stateSubject = CurrentValueSubject<VoiceMessagePreviewPlayerState, Never>(.stopped)
    private var backend: AudioPlaybackBackend?
    private var sourceURL: URL?
    private var decodedURL: URL?
    /// Bumped by `stop`, so a decode still running knows it was abandoned.
    private var generation = 0
    /// The session is shared with the recorder, so it's only released if playback took it.
    private var isHoldingSession = false
    private var progressTask: Task<Void, Never>?

    var statePublisher: AnyPublisher<VoiceMessagePreviewPlayerState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    init(audioSession: AudioSessionProxyProtocol,
         makeAudioPlayer: @escaping (URL) throws -> AudioPlaybackBackend = { try AVAudioPlayerBackend(url: $0) },
         clock: some Clock<Duration> = ContinuousClock()) {
        self.audioSession = audioSession
        self.makeAudioPlayer = makeAudioPlayer
        makeTickSleeper = { Self.tickSleeper(on: clock) }
    }

    isolated deinit {
        stop()
    }

    func play(fileURL: URL) async -> Result<Void, VoiceMessagePreviewPlayerError> {
        if backend == nil || sourceURL != fileURL {
            stop()
            guard await prepare(fileURL: fileURL) else { return .failure(.failed) }
        }
        guard let backend else { return .failure(.failed) }

        do {
            try audioSession.activateForPlayback()
        } catch {
            MXLog.error("Activating the audio session for playback failed")
            return .failure(.failed)
        }
        isHoldingSession = true
        guard backend.play() else {
            releaseSession()
            return .failure(.failed)
        }
        startProgressUpdates()
        return .success(())
    }

    func pause() {
        guard case .playing = stateSubject.value, let backend else { return }
        backend.pause()
        moveToPaused(backend)
    }

    func stop() {
        generation += 1
        backend?.stop()
        backend = nil
        sourceURL = nil
        stopProgressUpdates()
        releaseSession()
        if let decodedURL {
            try? FileManager.default.removeItem(at: decodedURL)
            self.decodedURL = nil
        }
        stateSubject.send(.stopped)
    }

    // MARK: - Private

    private func prepare(fileURL: URL) async -> Bool {
        generation += 1
        let preparingGeneration = generation
        let outputURL = VoiceMessageServices.temporaryDirectory.appending(path: "\(UUID().uuidString)-preview.caf")

        let isDecoded = await Task.detached {
            do {
                try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                _ = try VoiceMessageDecoder.decode(oggData: Data(contentsOf: fileURL), to: outputURL)
                return true
            } catch {
                return false
            }
        }.value

        guard isDecoded, preparingGeneration == generation, let backend = try? makeAudioPlayer(outputURL) else {
            if !isDecoded { MXLog.error("Decoding the voice message preview failed") }
            try? FileManager.default.removeItem(at: outputURL)
            return false
        }
        let backendID = ObjectIdentifier(backend)
        backend.finishHandler = { [weak self] in self?.finishPlaying(backendID: backendID) }
        self.backend = backend
        sourceURL = fileURL
        decodedURL = outputURL
        return true
    }

    /// `backendID` names the player that finished: a late callback from one that was since replaced is ignored,
    /// so it can't release the session or reset newer playback.
    private func finishPlaying(backendID: ObjectIdentifier) {
        guard let backend, ObjectIdentifier(backend) == backendID else { return }
        stopProgressUpdates()
        releaseSession()
        stateSubject.send(.stopped)
    }

    private func moveToPaused(_ backend: AudioPlaybackBackend) {
        stopProgressUpdates()
        releaseSession()
        stateSubject.send(.paused(progress: Self.progress(of: backend)))
    }

    private func releaseSession() {
        guard isHoldingSession else { return }
        isHoldingSession = false
        audioSession.deactivate()
    }

    private func startProgressUpdates() {
        stopProgressUpdates()
        stateSubject.send(.playing(progress: backend.map(Self.progress) ?? 0))
        let sleep = makeTickSleeper()
        progressTask = Task { [weak self] in
            var tick = 1
            while !Task.isCancelled {
                do { try await sleep(tick) } catch { return }
                guard !Task.isCancelled, let self, let backend = self.backend else { return }
                guard backend.isPlaying else {
                    // The system paused it (a call, Siri, the app suspending): let ▶︎ resume it.
                    MXLog.info("Voice message preview playback was interrupted")
                    self.moveToPaused(backend)
                    return
                }
                self.stateSubject.send(.playing(progress: Self.progress(of: backend)))
                tick += 1
            }
        }
    }

    private func stopProgressUpdates() {
        progressTask?.cancel()
        progressTask = nil
    }

    private static func progress(of backend: AudioPlaybackBackend) -> Double {
        guard backend.duration > 0 else { return 0 }
        return min(max(backend.currentTime / backend.duration, 0), 1)
    }

    /// Sleeps until tick `n` from now, so ticks don't drift when one runs late.
    private static func tickSleeper(on clock: some Clock<Duration>) -> @Sendable (Int) async throws -> Void {
        let start = clock.now
        return { tick in try await clock.sleep(until: start.advanced(by: progressInterval * tick), tolerance: nil) }
    }
}
