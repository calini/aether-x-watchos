//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// Turns an Ogg Opus voice message into a PCM file `AVAudioPlayer` can play.
nonisolated enum VoiceMessageDecoder {
    /// Ogg Opus → 48 kHz mono PCM CAF at `outputURL`, trimmed to the stream's real length
    /// (the final granule minus pre-skip). Stereo streams are downmixed. Blocking: call off the main actor.
    /// Returns the duration written.
    static func decode(oggData: Data, to outputURL: URL) throws(OpusCodecError) -> TimeInterval {
        let file: OggOpusFile
        do { file = try OggOpusReader.read(oggData) } catch { throw .decodingFailed }

        return try OpusCodec.decode(packets: file.packets,
                                    preSkip: file.preSkip,
                                    channelCount: file.channelCount,
                                    frameLimit: file.granulePosition - Int64(file.preSkip),
                                    to: outputURL)
    }
}
