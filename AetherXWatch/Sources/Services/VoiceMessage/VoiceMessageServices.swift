//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// A session's audio, shared by all its chats: one audio session for the recorder and both players, and one player for received messages.
struct VoiceMessageServices {
    /// Recordings, encoded messages and decoded previews waiting to be sent or deleted.
    nonisolated static let temporaryDirectory = URL.temporaryDirectory.appending(path: "VoiceMessages", directoryHint: .isDirectory)

    let audioSession: AudioSessionProxyProtocol
    let player: VoiceMessagePlayerProtocol

    /// Call once per session, before anything records.
    static func live(for clientProxy: ClientProxyProtocol) -> VoiceMessageServices {
        removeLeftoverFiles()
        let audioSession = AudioSessionProxy()
        return VoiceMessageServices(audioSession: audioSession,
                                    player: VoiceMessagePlayer(loadContent: { await clientProxy.loadMediaContent(for: $0) }, audioSession: audioSession))
    }

    /// Removes what an app killed mid-recording left behind.
    nonisolated static func removeLeftoverFiles(in directory: URL = temporaryDirectory) {
        guard FileManager.default.fileExists(atPath: directory.path()) else { return }
        do {
            try FileManager.default.removeItem(at: directory)
            MXLog.info("Removed leftover voice message files")
        } catch {
            MXLog.error("Removing leftover voice message files failed")
        }
    }
}
