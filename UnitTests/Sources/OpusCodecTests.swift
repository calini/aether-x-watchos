//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
@testable import AetherXWatch
import Testing

@Suite
struct OpusCodecTests {
    @Test
    func roundTripsATone() throws {
        let source = try makeTone(seconds: 1)
        let output = temporaryURL()
        defer { removeFiles(source, output) }

        let encoded = try OpusCodec.encode(fileAt: source)
        #expect((49...52).contains(encoded.packets.count))
        #expect(encoded.frameCount == 48000)

        let duration = try OpusCodec.decode(packets: encoded.packets, preSkip: encoded.preSkip, to: output)
        try expectLength(of: output, near: 48000)
        #expect(abs(duration - 1) <= 0.02)
    }

    @Test
    func encodesInChunks() throws {
        let source = try makeTone(seconds: 3)
        let output = temporaryURL()
        defer { removeFiles(source, output) }

        var chunkSizes: [AVAudioFrameCount] = []
        let encoded = try OpusCodec.encode(fileAt: source, chunkFrames: 4800) { chunkSizes.append($0) }
        #expect(chunkSizes.count == 30)
        #expect(chunkSizes.allSatisfy { $0 <= 4800 })
        #expect((149...152).contains(encoded.packets.count))
        #expect(encoded.frameCount == 144_000)

        _ = try OpusCodec.decode(packets: encoded.packets, preSkip: encoded.preSkip, to: output)
        try expectLength(of: output, near: 144_000)
    }

    @Test
    func resamplesOtherFormats() throws {
        let source = try makeTone(seconds: 1, sampleRate: 44100, channels: 2)
        let output = temporaryURL()
        defer { removeFiles(source, output) }

        let encoded = try OpusCodec.encode(fileAt: source, chunkFrames: 4410)
        #expect(abs(encoded.frameCount - 48000) <= 960)
        #expect((49...52).contains(encoded.packets.count))

        _ = try OpusCodec.decode(packets: encoded.packets, preSkip: encoded.preSkip, to: output)
        try expectLength(of: output, near: 48000)
    }

    @Test
    func selfTestPasses() {
        #expect(OpusCodec.selfTest())
    }

    /// Apple's decoder doesn't reject a malformed packet: it conceals it as one packet of silence.
    @Test
    func decodesGarbageToSilence() throws {
        let output = temporaryURL()
        defer { removeFiles(output) }

        let duration = try OpusCodec.decode(packets: [Data([1, 2, 3])], preSkip: 312, to: output)
        #expect(duration <= 0.02)

        let file = try AVAudioFile(forReading: output)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 960))
        try file.read(into: buffer)
        let samples = UnsafeBufferPointer(start: buffer.floatChannelData?[0], count: Int(buffer.frameLength))
        #expect(samples.allSatisfy { $0 == 0 })
    }

    // MARK: - Helpers

    private func makeTone(seconds: Int, sampleRate: Double = 48000, channels: AVAudioChannelCount = 1) throws -> URL {
        let url = temporaryURL()
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: channels, interleaved: false))
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let frames = AVAudioFrameCount(sampleRate) * AVAudioFrameCount(seconds)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        let samples = try #require(buffer.floatChannelData)
        buffer.frameLength = frames
        for channel in 0..<Int(channels) {
            for index in 0..<Int(frames) {
                samples[channel][index] = 0.5 * sin(2 * .pi * 440 * Float(index) / Float(sampleRate))
            }
        }
        try file.write(from: buffer)
        return url
    }

    private func expectLength(of url: URL, near frames: Int64) throws {
        let file = try AVAudioFile(forReading: url)
        #expect(abs(file.length - frames) <= 960)
        #expect(file.processingFormat.sampleRate == 48000)
        #expect(file.processingFormat.channelCount == 1)
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
    }

    private func removeFiles(_ urls: URL...) {
        urls.forEach { try? FileManager.default.removeItem(at: $0) }
    }
}
