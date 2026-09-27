//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
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

final class VoiceMessagePreviewPlayer: NSObject, VoiceMessagePreviewPlayerProtocol, AVAudioPlayerDelegate {
    private static let progressInterval = Duration.milliseconds(100)

    private let audioSession: AudioSessionProxyProtocol
    private let stateSubject = CurrentValueSubject<VoiceMessagePreviewPlayerState, Never>(.stopped)
    private var player: AVAudioPlayer?
    private var sourceURL: URL?
    private var decodedURL: URL?
    /// Bumped by `stop`, so a decode still running knows it was abandoned.
    private var generation = 0
    private var progressTask: Task<Void, Never>?

    var statePublisher: AnyPublisher<VoiceMessagePreviewPlayerState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    init(audioSession: AudioSessionProxyProtocol) {
        self.audioSession = audioSession
    }

    isolated deinit {
        stop()
    }

    func play(fileURL: URL) async -> Result<Void, VoiceMessagePreviewPlayerError> {
        if player == nil || sourceURL != fileURL {
            stop()
            guard await prepare(fileURL: fileURL) else { return .failure(.failed) }
        }
        guard let player else { return .failure(.failed) }

        do {
            try audioSession.activateForPlayback()
        } catch {
            MXLog.error("Activating the audio session for playback failed")
            return .failure(.failed)
        }
        guard player.play() else {
            audioSession.deactivate()
            return .failure(.failed)
        }
        startProgressUpdates()
        return .success(())
    }

    func pause() {
        guard let player, player.isPlaying else { return }
        player.pause()
        stopProgressUpdates()
        audioSession.deactivate()
        stateSubject.send(.paused(progress: progress(of: player)))
    }

    func stop() {
        generation += 1
        if let player {
            let wasPlaying = player.isPlaying
            player.stop()
            if wasPlaying { audioSession.deactivate() }
        }
        player = nil
        sourceURL = nil
        stopProgressUpdates()
        if let decodedURL {
            try? FileManager.default.removeItem(at: decodedURL)
            self.decodedURL = nil
        }
        stateSubject.send(.stopped)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in finishPlaying() }
    }

    // MARK: - Private

    private func prepare(fileURL: URL) async -> Bool {
        generation += 1
        let preparingGeneration = generation
        let outputURL = FileManager.default.temporaryDirectory.appending(path: "VoiceMessages/\(UUID().uuidString)-preview.caf")

        let isDecoded = await Task.detached {
            do {
                try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                _ = try VoiceMessageDecoder.decode(oggData: Data(contentsOf: fileURL), to: outputURL)
                return true
            } catch {
                return false
            }
        }.value

        guard isDecoded, preparingGeneration == generation, let player = try? AVAudioPlayer(contentsOf: outputURL) else {
            if !isDecoded { MXLog.error("Decoding the voice message preview failed") }
            try? FileManager.default.removeItem(at: outputURL)
            return false
        }
        player.delegate = self
        self.player = player
        sourceURL = fileURL
        decodedURL = outputURL
        return true
    }

    private func finishPlaying() {
        stopProgressUpdates()
        audioSession.deactivate()
        stateSubject.send(.stopped)
    }

    private func startProgressUpdates() {
        stopProgressUpdates()
        stateSubject.send(.playing(progress: player.map(progress) ?? 0))
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.progressInterval)
                guard !Task.isCancelled, let self, let player = self.player, player.isPlaying else { return }
                self.stateSubject.send(.playing(progress: self.progress(of: player)))
            }
        }
    }

    private func stopProgressUpdates() {
        progressTask?.cancel()
        progressTask = nil
    }

    private func progress(of player: AVAudioPlayer) -> Double {
        guard player.duration > 0 else { return 0 }
        return min(max(player.currentTime / player.duration, 0), 1)
    }
}
