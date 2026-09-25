//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementXWatch
import MatrixRustSDK
import Testing

struct SDKListenerTests {
    @Test
    func mainActorListenerDeliversInOrder() async {
        var received: [SyncServiceState] = []
        let listener = SDKListener<SyncServiceState>.onMainActor { received.append($0) }

        await Task.detached {
            listener.onUpdate(state: .running)
            listener.onUpdate(state: .offline)
            listener.onUpdate(state: .running)
        }.value
        for _ in 0..<50 where received.count < 3 {
            await Task.yield()
        }

        #expect(received == [.running, .offline, .running])
    }
}
