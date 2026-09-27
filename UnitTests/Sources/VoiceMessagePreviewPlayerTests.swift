//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Combine
@testable import ElementXWatch
import Testing

struct VoiceMessagePreviewPlayerTests {
    @Test
    func playsPausesAndStops() async throws {
        let (recording, message) = try encodedSilence()
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
        let (recording, message) = try encodedSilence()
        defer { [recording, message.fileURL].forEach { try? FileManager.default.removeItem(at: $0) } }
        let audioSession = AudioSessionProxyMock()
        let player = VoiceMessagePreviewPlayer(audioSession: audioSession)
        _ = await player.play(fileURL: message.fileURL)
        let started = ContinuousClock.now
        var states: [VoiceMessagePreviewPlayerState] = []
        let cancellable = player.statePublisher.sink { states.append($0) }
        let stalePlayer = try AVAudioPlayer(contentsOf: recording)

        player.audioPlayerDidFinishPlaying(stalePlayer, successfully: true)

        // The real end of the 1 s file comes after the stale callback's hop, so only it may stop playback.
        try await waitUntil { states.contains(.stopped) }
        #expect(ContinuousClock.now - started > .milliseconds(800))
        #expect(states.filter { $0 == .stopped }.count == 1)
        #expect(audioSession.deactivateCallsCount == 1)
        player.stop()
        cancellable.cancel()
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

    private func encodedSilence() throws -> (URL, EncodedVoiceMessage) {
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
