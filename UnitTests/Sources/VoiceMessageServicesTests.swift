//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

@testable import AetherXWatch
import Foundation
import Testing

struct VoiceMessageServicesTests {
    @Test
    func leftoverRecordingsAreRemoved() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "VoiceMessageServicesTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["recording.caf", "message.ogg", "abc-preview.caf"] {
            try Data([1, 2, 3]).write(to: directory.appending(path: name))
        }

        VoiceMessageServices.removeLeftoverFiles(in: directory)

        #expect(!FileManager.default.fileExists(atPath: directory.path()))
    }

    @Test
    func aMissingDirectoryIsFine() {
        let directory = FileManager.default.temporaryDirectory.appending(path: "VoiceMessageServicesTests-\(UUID().uuidString)", directoryHint: .isDirectory)

        VoiceMessageServices.removeLeftoverFiles(in: directory)

        #expect(!FileManager.default.fileExists(atPath: directory.path()))
    }
}
