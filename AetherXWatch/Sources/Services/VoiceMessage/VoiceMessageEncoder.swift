//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

nonisolated struct EncodedVoiceMessage: Equatable, Sendable {
    let fileURL: URL
    let duration: TimeInterval
    let size: UInt64
}

/// Turns a recorded PCM file into the Ogg Opus file a voice message sends.
nonisolated enum VoiceMessageEncoder {
    /// PCM CAF → `.ogg` next to it. Blocking: call off the main actor.
    static func encode(recordingAt url: URL) throws(OpusCodecError) -> EncodedVoiceMessage {
        let encoded = try OpusCodec.encode(fileAt: url)
        let data = OggOpusWriter.write(packets: encoded.packets, preSkip: encoded.preSkip, frameCount: encoded.frameCount)
        let fileURL = url.deletingPathExtension().appendingPathExtension("ogg")
        do { try data.write(to: fileURL, options: .atomic) } catch { throw .encodingFailed }

        let duration = Double(encoded.frameCount) / OpusCodec.sampleRate
        MXLog.info("Encoded a voice message: \(encoded.packets.count) packets, \(duration) s")
        return EncodedVoiceMessage(fileURL: fileURL, duration: duration, size: UInt64(data.count))
    }
}
