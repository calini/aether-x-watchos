//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
@testable import AetherXWatch
import Testing

@Suite
struct VoiceMessageEncoderTests {
    @Test
    func encodesARecordingToOggOpus() throws {
        let recording = try makeTone(seconds: 2)
        let expectedURL = recording.deletingPathExtension().appendingPathExtension("ogg")
        defer { removeFiles(recording, expectedURL) }

        let message = try VoiceMessageEncoder.encode(recordingAt: recording)

        #expect(message.fileURL == expectedURL)
        #expect(abs(message.duration - 2) <= 0.02)

        let data = try Data(contentsOf: message.fileURL)
        #expect(message.size == UInt64(data.count))

        let file = try OggOpusReader.read(data)
        #expect(file.channelCount == 1)
        #expect(file.inputSampleRate == 48000)
        #expect((99...102).contains(file.packets.count))
        #expect(file.granulePosition - Int64(file.preSkip) == 96000)
    }

    @Test
    func aMissingRecordingFails() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")

        #expect(throws: OpusCodecError.encodingFailed) { try VoiceMessageEncoder.encode(recordingAt: missing) }
    }

    // MARK: - Helpers

    private func makeTone(seconds: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
        let format = OpusCodec.pcmFormat
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let frames = AVAudioFrameCount(format.sampleRate) * AVAudioFrameCount(seconds)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        let samples = try #require(buffer.floatChannelData)
        buffer.frameLength = frames
        for index in 0..<Int(frames) {
            samples[0][index] = 0.5 * sin(2 * .pi * 440 * Float(index) / Float(format.sampleRate))
        }
        try file.write(from: buffer)
        return url
    }

    private func removeFiles(_ urls: URL...) {
        urls.forEach { try? FileManager.default.removeItem(at: $0) }
    }
}
