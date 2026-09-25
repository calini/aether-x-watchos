//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementXWatch
import MatrixRustSDK
import Testing

struct ClientProxyMappingTests {
    @Test
    func syncStatesMap() {
        #expect(SyncState(.idle) == .idle)
        #expect(SyncState(.terminated) == .idle)
        #expect(SyncState(.running) == .running)
        #expect(SyncState(.offline) == .offline)
        #expect(SyncState(.error) == .error)
    }

    @Test
    func verificationStatesMap() {
        #expect(SessionVerification(.verified) == .verified)
        #expect(SessionVerification(.unverified) == .unverified)
        #expect(SessionVerification(.unknown) == .unknown)
    }
}
