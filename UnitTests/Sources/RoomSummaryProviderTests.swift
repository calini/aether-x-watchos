//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import AetherXWatch
import MatrixRustSDK
import Testing

@Suite
struct RoomSummaryProviderTests {
    /// The Rust entries task borrows the `RoomList` the subscription owns, so the provider must keep it
    /// for its whole lifetime (releasing it early crashed on a tokio worker).
    @Test
    func startingKeepsTheSubscriptionAlive() async {
        let spy = SubscriptionSpy()
        let provider = RoomSummaryProvider(subscribe: spy.subscribe)

        await provider.start()

        #expect(spy.subscribeCount == 1)
        #expect(spy.subscription != nil)
        #expect(spy.subscription?.filters.count == 1)
        withExtendedLifetime(provider) { }
    }

    @Test
    func startingTwiceSubscribesOnce() async {
        let spy = SubscriptionSpy()
        let provider = RoomSummaryProvider(subscribe: spy.subscribe)

        await provider.start()
        await provider.start()

        #expect(spy.subscribeCount == 1)
        #expect(spy.subscription != nil)
    }

    @Test
    func releasingTheProviderReleasesTheSubscription() async {
        let spy = SubscriptionSpy()
        var provider: RoomSummaryProvider? = RoomSummaryProvider(subscribe: spy.subscribe)
        await provider?.start()

        provider = nil

        #expect(spy.subscription == nil)
    }
}

// MARK: - Helpers

private final class SubscriptionSpy {
    private(set) var subscribeCount = 0
    /// Weak so the tests see whether the provider keeps it alive.
    private(set) weak var subscription: SubscriptionFake?

    func subscribe(_ listener: RoomListEntriesListener) async throws -> RoomListEntriesSubscriptionProtocol {
        subscribeCount += 1
        let subscription = SubscriptionFake()
        self.subscription = subscription
        return subscription
    }
}

private final class SubscriptionFake: RoomListEntriesSubscriptionProtocol {
    private(set) var filters: [RoomListEntriesDynamicFilterKind] = []

    func setFilter(_ kind: RoomListEntriesDynamicFilterKind) {
        filters.append(kind)
    }
}
