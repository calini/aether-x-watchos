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
struct VoiceMessageDecoderTests {
    @Test
    func decodesAVoiceMessageToItsRealLength() throws {
        let recording = try makeTone(seconds: 1.5, channels: 1)
        let message = try VoiceMessageEncoder.encode(recordingAt: recording)
        let output = temporaryURL()
        defer { removeFiles(recording, message.fileURL, output) }

        let duration = try VoiceMessageDecoder.decode(oggData: Data(contentsOf: message.fileURL), to: output)

        #expect(duration == 1.5)
        let file = try AVAudioFile(forReading: output)
        #expect(file.length == 72000)
        #expect(file.processingFormat == OpusCodec.pcmFormat)
        // Stored as 16-bit integers, half the size of the processing format, since players cache these files.
        #expect(file.fileFormat.commonFormat == .pcmFormatInt16)
    }

    @Test
    func downmixesAStereoStream() throws {
        let ogg = try makeStereoOgg(seconds: 1)
        let output = temporaryURL()
        defer { removeFiles(output) }
        #expect(try OggOpusReader.read(ogg).channelCount == 2)

        let duration = try VoiceMessageDecoder.decode(oggData: ogg, to: output)

        #expect(duration == 1)
        let file = try AVAudioFile(forReading: output)
        #expect(file.length == 48000)
        #expect(file.processingFormat == OpusCodec.pcmFormat)
        #expect(try peak(of: file) > 0.1)
    }

    @Test
    func anEmptyStreamDecodesToNothing() throws {
        let output = temporaryURL()
        defer { removeFiles(output) }

        let duration = try VoiceMessageDecoder.decode(oggData: OggOpusWriter.write(packets: [], preSkip: 312, frameCount: 0), to: output)

        #expect(duration == 0)
    }

    @Test
    func stopsAtTheMaximumDuration() throws {
        let recording = try makeTone(seconds: 2, channels: 1)
        let message = try VoiceMessageEncoder.encode(recordingAt: recording)
        let output = temporaryURL()
        defer { removeFiles(recording, message.fileURL, output) }

        let duration = try VoiceMessageDecoder.decode(oggData: Data(contentsOf: message.fileURL), to: output, maximumDuration: 0.5)

        #expect(duration == 0.5)
        #expect(try AVAudioFile(forReading: output).length == 24000)
    }

    @Test
    func aHugeGranuleIsCutAtTheMaximumDuration() throws {
        // A sender can claim any length: here, a day of audio made of the same packets over and over.
        let recording = try makeTone(seconds: 1, channels: 1)
        let message = try VoiceMessageEncoder.encode(recordingAt: recording)
        let output = temporaryURL()
        defer { removeFiles(recording, message.fileURL, output) }
        let packets = try OggOpusReader.read(Data(contentsOf: message.fileURL)).packets
        let ogg = OggOpusWriter.write(packets: Array(repeating: packets, count: 5).flatMap(\.self), preSkip: 312, frameCount: 86400 * 48000)

        let duration = try VoiceMessageDecoder.decode(oggData: ogg, to: output, maximumDuration: 2)

        #expect(duration == 2)
        #expect(try AVAudioFile(forReading: output).length == 96000)
    }

    @Test
    func rejectsAFileOverTheSizeLimit() {
        let output = temporaryURL()
        defer { removeFiles(output) }

        #expect(throws: OpusCodecError.decodingFailed) {
            try VoiceMessageDecoder.decode(oggData: Data(count: VoiceMessageDecoder.maximumOggBytes + 1), to: output)
        }
    }

    @Test
    func rejectsDataThatIsNotOggOpus() {
        let output = temporaryURL()
        defer { removeFiles(output) }

        #expect(throws: OpusCodecError.decodingFailed) { try VoiceMessageDecoder.decode(oggData: Data("not a voice message".utf8), to: output) }
    }

    // MARK: - Helpers

    private func makeTone(seconds: Double, channels: AVAudioChannelCount) throws -> URL {
        let url = temporaryURL()
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: channels, interleaved: false))
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        defer { file.close() }
        try file.write(from: toneBuffer(seconds: seconds, format: format))
        return url
    }

    private func toneBuffer(seconds: Double, format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(seconds * format.sampleRate)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        let samples = try #require(buffer.floatChannelData)
        buffer.frameLength = frames
        for channel in 0..<Int(format.channelCount) {
            for index in 0..<Int(frames) {
                samples[channel][index] = 0.5 * sin(2 * .pi * 440 * Float(index) / Float(format.sampleRate))
            }
        }
        return buffer
    }

    /// A stereo Ogg Opus stream: the app only writes mono, so this encodes stereo itself and patches the OpusHead.
    private func makeStereoOgg(seconds: Double) throws -> Data {
        let pcmFormat = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: false))
        var description = AudioStreamBasicDescription(mSampleRate: 48000, mFormatID: kAudioFormatOpus, mFormatFlags: 0, mBytesPerPacket: 0,
                                                      mFramesPerPacket: 960, mBytesPerFrame: 0, mChannelsPerFrame: 2, mBitsPerChannel: 0, mReserved: 0)
        let opusFormat = try #require(AVAudioFormat(streamDescription: &description))
        let encoder = try #require(AVAudioConverter(from: pcmFormat, to: opusFormat))
        var input: AVAudioPCMBuffer? = try toneBuffer(seconds: seconds, format: pcmFormat)
        let output = AVAudioCompressedBuffer(format: opusFormat, packetCapacity: 100, maximumPacketSize: max(encoder.maximumOutputPacketSize, 1))
        var packets: [Data] = []
        while true {
            output.packetCount = 0
            output.byteLength = 0
            let status = encoder.convert(to: output, error: nil) { _, inputStatus in
                guard let buffer = input else {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                input = nil
                inputStatus.pointee = .haveData
                return buffer
            }
            #expect(status != .error)
            let descriptions = try #require(output.packetDescriptions)
            for index in 0..<Int(output.packetCount) {
                packets.append(Data(bytes: output.data.advanced(by: Int(descriptions[index].mStartOffset)), count: Int(descriptions[index].mDataByteSize)))
            }
            if status != .haveData { break }
        }

        var ogg = OggOpusWriter.write(packets: packets, preSkip: 312, frameCount: Int64(seconds * 48000))
        // The first page: a 27-byte header, 1 lacing value, then OpusHead, whose channel count is at offset 9.
        ogg[27 + 1 + 9] = 2
        ogg.replaceSubrange(22..<26, with: [0, 0, 0, 0])
        let firstPageLength = 27 + 1 + Int(ogg[27])
        let crc = OggCRC.checksum(ogg[0..<firstPageLength])
        ogg.replaceSubrange(22..<26, with: withUnsafeBytes(of: crc.littleEndian, Array.init))
        return ogg
    }

    private func peak(of file: AVAudioFile) throws -> Float {
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let samples = UnsafeBufferPointer(start: buffer.floatChannelData?[0], count: Int(buffer.frameLength))
        return samples.map(abs).max() ?? 0
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
    }

    private func removeFiles(_ urls: URL...) {
        urls.forEach { try? FileManager.default.removeItem(at: $0) }
    }
}
