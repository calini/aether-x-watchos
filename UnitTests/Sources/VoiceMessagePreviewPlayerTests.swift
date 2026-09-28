//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Combine
@testable import AetherXWatch
import Testing

struct VoiceMessagePreviewPlayerTests {
    @Test
    func playsPausesAndStops() async throws {
        let (recording, message) = try Self.encodedSilence()
        defer { [recording, message.fileURL].forEach { try? FileManager.default.removeItem(at: $0) } }
        let audioSession = AudioSessionProxyMock()
        let player = VoiceMessagePreviewPlayer(audioSession: audioSession)
        var states: [VoiceMessagePreviewPlayerState] = []
        let cancellable = player.statePublisher.sink { states.append($0) }
        let previewsBefore = try decodedPreviews()

        let result = await player.play(fileURL: message.fileURL)

        #expect(throws: Never.self) { try result.get() }
        #expect(audioSession.activateForPlaybackCallsCount == 1)
        #expect(try decodedPreviews().subtracting(previewsBefore).count == 1)
        guard case .playing = states.last else {
            Issue.record("Expected playing")
            return
        }

        player.pause()
        guard case .paused = states.last else {
            Issue.record("Expected paused")
            return
        }
        #expect(audioSession.deactivateCallsCount == 1)

        player.stop()
        #expect(states.last == .stopped)
        #expect(try decodedPreviews().subtracting(previewsBefore).isEmpty)
        cancellable.cancel()
    }

    @Test
    func aLateFinishFromAnotherPlayerIsIgnored() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        _ = await harness.player.play(fileURL: harness.message.fileURL)
        let staleFinish = try #require(harness.backends[0].finishHandler)
        harness.player.stop()
        _ = await harness.player.play(fileURL: harness.message.fileURL)
        let deactivations = harness.audioSession.deactivateCallsCount

        staleFinish()

        #expect(harness.states.values.last == .playing(progress: 0))
        #expect(harness.audioSession.deactivateCallsCount == deactivations)
    }

    @Test
    func theEndStopsAndReleasesTheSession() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        _ = await harness.player.play(fileURL: harness.message.fileURL)

        harness.backends[0].finishHandler?()

        #expect(harness.states.values.last == .stopped)
        #expect(harness.audioSession.deactivateCallsCount == 1)
        try await waitUntil { harness.clock.sleeperCount == 0 }
    }

    @Test
    func anInterruptionPausesAndPlayResumes() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        _ = await harness.player.play(fileURL: harness.message.fileURL)
        harness.backends[0].currentTime = 0.5

        // The system paused the player, as a call or Siri does.
        harness.backends[0].isPlaying = false
        try await harness.tick()

        #expect(harness.states.values.last == .paused(progress: 0.5))
        #expect(harness.audioSession.deactivateCallsCount == 1)
        try await waitUntil { harness.clock.sleeperCount == 0 }

        harness.backends[0].isPlaying = true
        let result = await harness.player.play(fileURL: harness.message.fileURL)

        #expect(throws: Never.self) { try result.get() }
        #expect(harness.states.values.last == .playing(progress: 0.5))
        #expect(harness.backends.count == 1)
        #expect(harness.backends[0].playCallsCount == 2)
        #expect(harness.audioSession.activateForPlaybackCallsCount == 2)

        harness.player.pause()

        #expect(harness.states.values.last == .paused(progress: 0.5))
        #expect(harness.backends[0].pauseCallsCount == 1)
        #expect(harness.audioSession.deactivateCallsCount == 2)
    }

    @Test
    func stoppingAfterAnInterruptionLeavesTheSessionAlone() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        _ = await harness.player.play(fileURL: harness.message.fileURL)
        harness.backends[0].isPlaying = false
        try await harness.tick()

        // The recorder may be using the shared session by now.
        harness.player.stop()

        #expect(harness.states.values.last == .stopped)
        #expect(harness.audioSession.deactivateCallsCount == 1)
    }

    @Test
    func aFileThatIsNotOggFails() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).ogg")
        try Data("not a voice message".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let audioSession = AudioSessionProxyMock()
        let player = VoiceMessagePreviewPlayer(audioSession: audioSession)

        let result = await player.play(fileURL: url)

        #expect(throws: VoiceMessagePreviewPlayerError.failed) { try result.get() }
        #expect(!audioSession.activateForPlaybackCalled)
    }

    // MARK: - Helpers

    /// A preview player with mock audio players and a test clock, over an encoded second of silence.
    private final class Harness {
        let audioSession = AudioSessionProxyMock()
        let clock = TestClock()
        let recording: URL
        let message: EncodedVoiceMessage
        let states = Recorder<VoiceMessagePreviewPlayerState>()
        private(set) var backends: [AudioPlaybackBackendMock] = []
        private(set) var player: VoiceMessagePreviewPlayer!
        private var cancellable: AnyCancellable?

        init() throws {
            (recording, message) = try VoiceMessagePreviewPlayerTests.encodedSilence()
            player = VoiceMessagePreviewPlayer(audioSession: audioSession,
                                               makeAudioPlayer: { [unowned self] _ in
                                                   let backend = AudioPlaybackBackendMock()
                                                   backend.duration = 1
                                                   backend.currentTime = 0
                                                   backend.isPlaying = true
                                                   backend.playReturnValue = true
                                                   backends.append(backend)
                                                   return backend
                                               },
                                               clock: clock)
            cancellable = player.statePublisher.sink { [states] in states.values.append($0) }
        }

        /// Fires the next 0.1 s progress update.
        func tick() async throws {
            try await waitUntil { clock.sleeperCount == 1 }
            let count = states.values.count
            clock.advance(by: .milliseconds(100))
            try await waitUntil { states.values.count > count }
        }

        func removeFiles() {
            player.stop()
            [recording, message.fileURL].forEach { try? FileManager.default.removeItem(at: $0) }
        }
    }


    private static func encodedSilence() throws -> (URL, EncodedVoiceMessage) {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).caf")
        let format = OpusCodec.pcmFormat
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000))
        let samples = try #require(buffer.floatChannelData)
        buffer.frameLength = 48000
        // Silent: these tests really play the file, through the Mac's speakers when run on a simulator.
        samples[0].update(repeating: 0, count: 48000)
        try file.write(from: buffer)
        file.close()
        return try (url, VoiceMessageEncoder.encode(recordingAt: url))
    }

    private func decodedPreviews() throws -> Set<String> {
        let directory = FileManager.default.temporaryDirectory.appending(path: "VoiceMessages")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path())) ?? []
        return Set(names.filter { $0.hasSuffix("-preview.caf") })
    }
}
