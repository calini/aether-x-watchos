//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

nonisolated struct SessionDirectories: Hashable, Codable {
    let dataDirectory: URL
    let cacheDirectory: URL

    var dataPath: String {
        dataDirectory.path(percentEncoded: false)
    }

    var cachePath: String {
        cacheDirectory.path(percentEncoded: false)
    }

    // MARK: Data Management

    /// Removes the directories from disk if they have been created.
    func delete() {
        do {
            if FileManager.default.fileExists(atPath: dataDirectory.path(percentEncoded: false)) {
                try FileManager.default.removeItem(at: dataDirectory)
            }
        } catch {
            MXLog.error("Failed deleting the session data: \(error)")
        }
        do {
            if FileManager.default.fileExists(atPath: cacheDirectory.path(percentEncoded: false)) {
                try FileManager.default.removeItem(at: cacheDirectory)
            }
        } catch {
            MXLog.error("Failed deleting the session caches: \(error)")
        }
    }

    /// Check that mission critical files (the crypto db) are still in the right place when restoring a session
    /// iOS might decide to move the app with its user defaults and keychain but without
    /// some of the files stored in the shared container e.g. after a device transfer, offloading etc.
    /// If that happens we should fail the session restoration.
    func isNonTransientUserDataValid() -> Bool {
        FileManager.default.fileExists(atPath: dataPath.appending("/matrix-sdk-crypto.sqlite3"))
    }
}

nonisolated extension SessionDirectories {
    /// Creates a fresh set of session directories for a new user.
    init() {
        let sessionDirectoryName = UUID().uuidString
        self.init(dataDirectoryName: sessionDirectoryName, cacheDirectoryName: sessionDirectoryName)
    }

    /// Resolves stored directory names against the current container's base directories.
    init(dataDirectoryName: String, cacheDirectoryName: String) {
        dataDirectory = .sessionsBaseDirectory.appending(component: dataDirectoryName)
        cacheDirectory = .sessionCachesBaseDirectory.appending(component: cacheDirectoryName)
    }
}

nonisolated extension SessionDirectories {
    // Not declared explicitly: the struct's synthesized memberwise initialiser already
    // provides `init(dataDirectory:cacheDirectory:)` since no initialiser is defined in its body.

    /// The SDK expects both directories to exist before building a client.
    func create() throws {
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

nonisolated extension URL {
    static var sessionsBaseDirectory: URL {
        .applicationSupportDirectory.appending(component: "Sessions", directoryHint: .isDirectory)
    }

    static var sessionCachesBaseDirectory: URL {
        .cachesDirectory.appending(component: "Sessions", directoryHint: .isDirectory)
    }

    static var logsDirectory: URL {
        .cachesDirectory.appending(component: "Logs", directoryHint: .isDirectory)
    }
}

nonisolated extension SessionDirectories: CustomStringConvertible {
    var description: String {
        "Data: \(dataPath) Caches: \(cachePath)"
    }
}
