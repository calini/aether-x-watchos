//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// Turns an Ogg Opus voice message into a PCM file `AVAudioPlayer` can play.
nonisolated enum VoiceMessageDecoder {
    /// Larger files are refused: a 15-minute message at 24 kbps is about 2.7 MB.
    static let maximumOggBytes = 5_000_000
    /// Longer streams are cut here. Element Web records up to 15 minutes; the cap bounds what a hostile
    /// sender's granule can make us write (at most about 86 MB of 16-bit PCM) and how long decoding runs.
    static let maximumDuration: TimeInterval = 15 * 60

    /// Ogg Opus → 48 kHz mono PCM CAF at `outputURL`, trimmed to the stream's real length
    /// (the final granule minus pre-skip) and to `maximumDuration`. Stereo streams are downmixed.
    /// Blocking: call off the main actor. Returns the duration written.
    static func decode(oggData: Data, to outputURL: URL, maximumDuration: TimeInterval = maximumDuration) throws(OpusCodecError) -> TimeInterval {
        guard oggData.count <= maximumOggBytes else { throw .decodingFailed }
        let file: OggOpusFile
        do { file = try OggOpusReader.read(oggData) } catch { throw .decodingFailed }

        let maximumFrames = Int64(maximumDuration * OpusCodec.sampleRate)
        return try OpusCodec.decode(packets: file.packets,
                                    preSkip: file.preSkip,
                                    channelCount: file.channelCount,
                                    frameLimit: min(file.granulePosition - Int64(file.preSkip), maximumFrames),
                                    to: outputURL)
    }
}
