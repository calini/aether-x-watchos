//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation

nonisolated enum OpusCodecError: Error, Equatable {
    case unavailable
    case encodingFailed
    case decodingFailed
}

nonisolated struct OpusEncodedAudio: Sendable {
    let packets: [Data]
    /// Frames a decoder drops from the start of its output (Ogg Opus `pre-skip`).
    let preSkip: UInt16
    /// 48 kHz PCM frames fed to the encoder.
    let frameCount: Int64
}

/// Opus (20 ms packets, 24 kbps, mono) on Apple's `AVAudioConverter`, streaming through files in chunks to bound memory.
nonisolated enum OpusCodec {
    static let sampleRate = 48000.0
    static let framesPerPacket: AVAudioFrameCount = 960
    static let bitRate = 24000
    /// libopus's encoder lookahead at 48 kHz, used when the converter doesn't report its priming.
    static let defaultPreSkip: UInt16 = 312

    static var pcmFormat: AVAudioFormat {
        AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
    }

    /// Encodes a PCM file (any format; converted to 48 kHz mono Float32) in chunks of `chunkFrames`.
    /// `onChunkRead` observes each chunk read from the source file.
    static func encode(fileAt url: URL,
                       chunkFrames: AVAudioFrameCount = 48000,
                       onChunkRead: @escaping (AVAudioFrameCount) -> Void = { _ in }) throws(OpusCodecError) -> OpusEncodedAudio {
        guard let opusFormat = makeOpusFormat(), let encoder = AVAudioConverter(from: pcmFormat, to: opusFormat) else { throw .unavailable }
        encoder.bitRate = bitRate

        let file: AVAudioFile
        do { file = try AVAudioFile(forReading: url) } catch { throw .encodingFailed }
        let source = try PCMSource(file: file, chunkFrames: chunkFrames, onChunkRead: onChunkRead)

        let output = AVAudioCompressedBuffer(format: opusFormat, packetCapacity: 50, maximumPacketSize: max(encoder.maximumOutputPacketSize, 1))
        var packets: [Data] = []
        var frameCount: Int64 = 0
        var sourceFailed = false

        while true {
            output.packetCount = 0
            output.byteLength = 0
            var conversionError: NSError?
            let status = encoder.convert(to: output, error: &conversionError) { _, inputStatus in
                do {
                    guard let buffer = try source.next() else {
                        inputStatus.pointee = .endOfStream
                        return nil
                    }
                    frameCount += Int64(buffer.frameLength)
                    inputStatus.pointee = .haveData
                    return buffer
                } catch {
                    sourceFailed = true
                    inputStatus.pointee = .endOfStream
                    return nil
                }
            }
            guard status != .error, !sourceFailed else { throw .encodingFailed }
            packets.append(contentsOf: packetData(in: output))
            if status == .endOfStream { break }
        }

        return OpusEncodedAudio(packets: packets, preSkip: preSkip(of: encoder), frameCount: frameCount)
    }

    /// Decodes packets to a 48 kHz mono PCM CAF at `outputURL`, dropping `preSkip` frames, in chunks.
    /// Returns the duration written.
    static func decode(packets: [Data], preSkip: UInt16, to outputURL: URL) throws(OpusCodecError) -> TimeInterval {
        guard let opusFormat = makeOpusFormat(), let decoder = AVAudioConverter(from: opusFormat, to: pcmFormat) else { throw .unavailable }
        // Apple's decoder already drops 120 frames itself (any primeMethod), so audio starts ~2.5 ms early after pre-skip.

        let file: AVAudioFile
        do {
            file = try AVAudioFile(forWriting: outputURL, settings: pcmFormat.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        } catch {
            throw .decodingFailed
        }
        defer { file.close() }

        guard let output = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: framesPerPacket * 5) else { throw .decodingFailed }
        var remainingPackets = packets[...]
        var framesToSkip = AVAudioFrameCount(preSkip)
        var framesWritten: Int64 = 0

        while true {
            output.frameLength = 0
            var conversionError: NSError?
            let status = decoder.convert(to: output, error: &conversionError) { _, inputStatus in
                guard let packet = remainingPackets.popFirst() else {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                inputStatus.pointee = .haveData
                return compressedBuffer(for: packet, format: opusFormat)
            }
            guard status != .error else { throw .decodingFailed }

            let skipped = min(framesToSkip, output.frameLength)
            framesToSkip -= skipped
            if output.frameLength > skipped {
                do { try file.write(from: dropping(skipped, from: output)) } catch { throw .decodingFailed }
                framesWritten += Int64(output.frameLength - skipped)
            }
            if status == .endOfStream { break }
        }

        return Double(framesWritten) / sampleRate
    }

    /// Round trip on a generated tone; true when watchOS has both codec directions.
    static func selfTest() -> Bool {
        let directory = FileManager.default.temporaryDirectory
        let sourceURL = directory.appendingPathComponent("opus-self-test-\(UUID().uuidString).caf")
        let decodedURL = directory.appendingPathComponent("opus-self-test-\(UUID().uuidString).caf")
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: decodedURL)
        }

        do {
            try writeTone(to: sourceURL, frames: AVAudioFrameCount(sampleRate))
            let encoded = try encode(fileAt: sourceURL)
            let duration = try decode(packets: encoded.packets, preSkip: encoded.preSkip, to: decodedURL)
            let passed = !encoded.packets.isEmpty && abs(duration - 1) <= Double(framesPerPacket) / sampleRate
            MXLog.info("Opus self-test \(passed ? "passed" : "failed"): \(encoded.packets.count) packets, \(duration) s")
            return passed
        } catch {
            MXLog.error("Opus self-test failed")
            return false
        }
    }

    // MARK: - Private

    private static func makeOpusFormat() -> AVAudioFormat? {
        var description = AudioStreamBasicDescription(mSampleRate: sampleRate,
                                                      mFormatID: kAudioFormatOpus,
                                                      mFormatFlags: 0,
                                                      mBytesPerPacket: 0,
                                                      mFramesPerPacket: framesPerPacket,
                                                      mBytesPerFrame: 0,
                                                      mChannelsPerFrame: 1,
                                                      mBitsPerChannel: 0,
                                                      mReserved: 0)
        return AVAudioFormat(streamDescription: &description)
    }

    private static func preSkip(of encoder: AVAudioConverter) -> UInt16 {
        let leadingFrames = encoder.primeInfo.leadingFrames
        guard leadingFrames > 0, leadingFrames <= AVAudioFrameCount(UInt16.max) else { return defaultPreSkip }
        return UInt16(leadingFrames)
    }

    private static func packetData(in buffer: AVAudioCompressedBuffer) -> [Data] {
        guard let descriptions = buffer.packetDescriptions else { return [] }
        return (0..<Int(buffer.packetCount)).map { index in
            let description = descriptions[index]
            return Data(bytes: buffer.data.advanced(by: Int(description.mStartOffset)), count: Int(description.mDataByteSize))
        }
    }

    private static func compressedBuffer(for packet: Data, format: AVAudioFormat) -> AVAudioCompressedBuffer {
        let buffer = AVAudioCompressedBuffer(format: format, packetCapacity: 1, maximumPacketSize: max(packet.count, 1))
        packet.copyBytes(to: buffer.data.assumingMemoryBound(to: UInt8.self), count: packet.count)
        buffer.packetDescriptions?[0] = AudioStreamPacketDescription(mStartOffset: 0, mVariableFramesInPacket: 0, mDataByteSize: UInt32(packet.count))
        buffer.packetCount = 1
        buffer.byteLength = UInt32(packet.count)
        return buffer
    }

    /// The tail of `buffer` after its first `frames` frames.
    private static func dropping(_ frames: AVAudioFrameCount, from buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard frames > 0,
              let tail = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength - frames),
              let source = buffer.floatChannelData, let destination = tail.floatChannelData else { return buffer }
        tail.frameLength = buffer.frameLength - frames
        destination[0].update(from: source[0].advanced(by: Int(frames)), count: Int(tail.frameLength))
        return tail
    }

    private static func writeTone(to url: URL, frames: AVAudioFrameCount) throws {
        let file = try AVAudioFile(forWriting: url, settings: pcmFormat.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        defer { file.close() }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: frames), let samples = buffer.floatChannelData else {
            throw OpusCodecError.encodingFailed
        }
        buffer.frameLength = frames
        for index in 0..<Int(frames) {
            samples[0][index] = 0.5 * sin(2 * .pi * 440 * Float(index) / Float(sampleRate))
        }
        try file.write(from: buffer)
    }
}

/// Reads a PCM file in chunks, resampling to 48 kHz mono Float32 when it's in another format.
private nonisolated final class PCMSource {
    private let file: AVAudioFile
    private let chunkFrames: AVAudioFrameCount
    private let onChunkRead: (AVAudioFrameCount) -> Void
    private let resampler: AVAudioConverter?
    private var isResamplerDrained = false

    init(file: AVAudioFile, chunkFrames: AVAudioFrameCount, onChunkRead: @escaping (AVAudioFrameCount) -> Void) throws(OpusCodecError) {
        self.file = file
        self.chunkFrames = max(chunkFrames, 1)
        self.onChunkRead = onChunkRead
        if file.processingFormat == OpusCodec.pcmFormat {
            resampler = nil
        } else {
            guard let converter = AVAudioConverter(from: file.processingFormat, to: OpusCodec.pcmFormat) else { throw .encodingFailed }
            resampler = converter
        }
    }

    /// The next chunk at 48 kHz mono Float32, or nil at the end of the file.
    func next() throws -> AVAudioPCMBuffer? {
        guard let resampler else { return try readChunk() }
        let ratio = OpusCodec.sampleRate / file.processingFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(chunkFrames) * ratio).rounded(.up)) + 1024

        while !isResamplerDrained {
            guard let output = AVAudioPCMBuffer(pcmFormat: OpusCodec.pcmFormat, frameCapacity: capacity) else { throw OpusCodecError.encodingFailed }
            var readError: Error?
            var conversionError: NSError?
            let status = resampler.convert(to: output, error: &conversionError) { _, inputStatus in
                do {
                    guard let chunk = try self.readChunk() else {
                        inputStatus.pointee = .endOfStream
                        return nil
                    }
                    inputStatus.pointee = .haveData
                    return chunk
                } catch {
                    readError = error
                    inputStatus.pointee = .endOfStream
                    return nil
                }
            }
            if let readError { throw readError }
            guard status != .error else { throw OpusCodecError.encodingFailed }
            isResamplerDrained = status == .endOfStream
            if output.frameLength > 0 { return output }
        }
        return nil
    }

    private func readChunk() throws -> AVAudioPCMBuffer? {
        guard file.framePosition < file.length else { return nil }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: chunkFrames) else { throw OpusCodecError.encodingFailed }
        try file.read(into: buffer, frameCount: chunkFrames)
        guard buffer.frameLength > 0 else { return nil }
        onChunkRead(buffer.frameLength)
        return buffer
    }
}
