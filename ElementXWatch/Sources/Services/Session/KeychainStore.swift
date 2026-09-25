//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import Security

// sourcery: AutoMockable
nonisolated protocol KeychainStoreProtocol: Sendable {
    func restorationToken() -> RestorationToken?
    func setRestorationToken(_ token: RestorationToken)
    func removeRestorationToken()
}

/// Stores the single signed-in account's restoration token in the keychain.
nonisolated final class KeychainStore: KeychainStoreProtocol {
    private static let account = "restorationToken"

    private let service: String

    init(service: String = "io.ilie.elementx.watch.sessions") {
        self.service = service
    }

    func restorationToken() -> RestorationToken? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound { MXLog.error("Keychain read failed: \(status)") }
            return nil
        }

        do {
            return try JSONDecoder().decode(RestorationToken.self, from: data)
        } catch {
            MXLog.error("Stored restoration token is unreadable: \(error)")
            return nil
        }
    }

    func setRestorationToken(_ token: RestorationToken) {
        guard let data = try? JSONEncoder().encode(token) else {
            return MXLog.error("Failed encoding the restoration token")
        }

        let attributes: [String: Any] = [kSecValueData as String: data,
                                         kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        var status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(baseQuery.merging(attributes) { $1 } as CFDictionary, nil)
        }
        if status != errSecSuccess {
            MXLog.error("Keychain write failed: \(status)")
        }
    }

    func removeRestorationToken() {
        let status = SecItemDelete(baseQuery as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            MXLog.error("Keychain delete failed: \(status)")
        }
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: Self.account]
    }
}
