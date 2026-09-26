//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementXWatch
import Foundation
import MatrixRustSDK
import Testing

@Suite
struct ChatScreenViewModelTests {
    @Test
    func appearSubscribesMarksReadAndShowsVisibleItems() async throws {
        let (viewModel, proxy, items) = makeViewModel()

        viewModel.context.send(viewAction: .appear)
        items.send([.event("1", body: "Hi"), TimelineItem(id: "h", kind: .hidden), .event("2", body: "There")])

        try await waitUntil { viewModel.context.viewState.items.map(\.id) == ["1", "2"] }
        #expect(proxy.subscribeCallsCount == 1)
        try await waitUntil { proxy.markAsReadCallsCount >= 1 }
    }

    @Test
    func sendTrimsAndRepliesToTheSelectedMessage() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        proxy.sendMessageInReplyToReturnValue = .success(())
        let target = EventItem.fixture(eventID: "$target")

        viewModel.context.send(viewAction: .reply(target))
        viewModel.context.send(viewAction: .send("  On my way  "))

        try await waitUntil { proxy.sendMessageInReplyToCallsCount == 1 }
        #expect(proxy.sendMessageInReplyToReceivedArguments?.message == "On my way")
        #expect(proxy.sendMessageInReplyToReceivedArguments?.eventID == "$target")
        #expect(viewModel.context.viewState.replyingTo == nil)
    }

    @Test
    func blankMessagesAreIgnored() async {
        let (viewModel, proxy, _) = makeViewModel()
        viewModel.context.send(viewAction: .send("   \n "))
        for _ in 0..<10 { await Task.yield() }
        #expect(proxy.sendMessageInReplyToCallsCount == 0)
    }

    @Test
    func sendFailuresAreShown() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        proxy.sendMessageInReplyToReturnValue = .failure(.sdkError("offline"))

        viewModel.context.send(viewAction: .send("Hello"))

        try await waitUntil { viewModel.context.viewState.bindings.errorMessage == WatchStrings.sendFailed }
        #expect(viewModel.context.viewState.draft == ChatDraft(text: "Hello", replyingTo: nil))
    }

    @Test
    func retryDraftResendsTheSameMessageAndReplyTarget() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        proxy.sendMessageInReplyToReturnValue = .failure(.sdkError("offline"))
        let target = EventItem.fixture(eventID: "$target")

        viewModel.context.send(viewAction: .reply(target))
        viewModel.context.send(viewAction: .send("On my way"))
        try await waitUntil { viewModel.context.viewState.bindings.errorMessage == WatchStrings.sendFailed }
        #expect(viewModel.context.viewState.replyingTo == target)

        proxy.sendMessageInReplyToReturnValue = .success(())
        viewModel.context.send(viewAction: .retryDraft)

        try await waitUntil { proxy.sendMessageInReplyToCallsCount == 2 }
        #expect(proxy.sendMessageInReplyToReceivedArguments?.message == "On my way")
        #expect(proxy.sendMessageInReplyToReceivedArguments?.eventID == "$target")
        try await waitUntil { viewModel.context.viewState.draft == nil }
        #expect(viewModel.context.viewState.replyingTo == nil)
    }

    @Test
    func failedMessagesCanBeRetried() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        proxy.retrySendReturnValue = .failure(.sdkError("still offline"))
        let failed = EventItem.fixture(eventID: nil, sendState: .failed)

        viewModel.context.send(viewAction: .retry(failed))

        try await waitUntil { proxy.retrySendCallsCount == 1 }
        #expect(proxy.retrySendReceivedItemID == failed.itemID)
        try await waitUntil { viewModel.context.viewState.bindings.errorMessage == WatchStrings.resendFailed }
    }

    @Test
    func reactingTogglesTheReactionAndClosesTheSheet() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        proxy.toggleReactionToReturnValue = .success(())
        let item = EventItem.fixture(eventID: "$e")
        viewModel.context.send(viewAction: .showActions(item))
        #expect(viewModel.context.viewState.bindings.actionsItem == item)

        viewModel.context.send(viewAction: .react(key: "👍", item: item))

        #expect(viewModel.context.viewState.bindings.actionsItem == nil)
        try await waitUntil { proxy.toggleReactionToCallsCount == 1 }
        #expect(proxy.toggleReactionToReceivedArguments?.key == "👍")
    }

    @Test
    func paginationStopsAtTheStart() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        proxy.paginateBackwardsReturnValue = .success(true)

        viewModel.context.send(viewAction: .paginateBackwards)
        try await waitUntil { viewModel.context.viewState.reachedStart }
        viewModel.context.send(viewAction: .paginateBackwards)
        for _ in 0..<10 { await Task.yield() }

        #expect(proxy.paginateBackwardsCallsCount == 1)
        #expect(!viewModel.context.viewState.isPaginating)
    }

    @Test
    func paginationFailuresCanBeRetried() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        proxy.paginateBackwardsReturnValue = .failure(.sdkError("offline"))

        viewModel.context.send(viewAction: .paginateBackwards)

        try await waitUntil { viewModel.context.viewState.paginationFailed }
        #expect(!viewModel.context.viewState.reachedStart)

        viewModel.context.send(viewAction: .paginateBackwards)

        try await waitUntil { proxy.paginateBackwardsCallsCount == 2 }
    }

    @Test
    func paginationRequestIDIncrementsOnEachNonFinalPageOnly() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        proxy.paginateBackwardsReturnValue = .success(false)

        viewModel.context.send(viewAction: .paginateBackwards)
        try await waitUntil { viewModel.context.viewState.paginationRequestID == 1 }

        viewModel.context.send(viewAction: .paginateBackwards)
        try await waitUntil { viewModel.context.viewState.paginationRequestID == 2 }

        proxy.paginateBackwardsReturnValue = .success(true)
        viewModel.context.send(viewAction: .paginateBackwards)
        try await waitUntil { viewModel.context.viewState.reachedStart }

        #expect(viewModel.context.viewState.paginationRequestID == 2)
    }

    @Test
    func showLocationOpensAOneOffLocation() {
        let (viewModel, _, _) = makeViewModel()
        let geoURI = GeoURI(latitude: 51.5072, longitude: -0.1276, uncertainty: nil)
        let item = EventItem.fixture(eventID: "$pin", body: .location(LocationBody(geoURI: geoURI, description: "The pub", body: "")))

        viewModel.context.send(viewAction: .showLocation(item))

        #expect(viewModel.context.viewState.bindings.locationMap?.mode == .location(geoURI, description: "The pub"))
    }

    @Test
    func showLocationIgnoresALocationThatCouldNotBeParsed() {
        let (viewModel, _, _) = makeViewModel()
        let item = EventItem.fixture(eventID: "$pin", body: .location(LocationBody(geoURI: nil, description: nil, body: "")))

        viewModel.context.send(viewAction: .showLocation(item))

        #expect(viewModel.context.viewState.bindings.locationMap == nil)
    }

    @Test
    func showLocationFollowsARunningLiveShare() async throws {
        let shares = CurrentValueSubject<[LiveLocationSummary], Never>([.fixture(userID: "@bob:example.org", beaconID: "$beacon", geoURI: park)])
        let (viewModel, _, _) = makeViewModel(liveLocations: shares)
        try await waitUntil { viewModel.context.viewState.liveLocations?.count == 1 }

        viewModel.context.send(viewAction: .showLocation(liveItem(isLive: true)))

        #expect(viewModel.context.viewState.bindings.locationMap?.mode == .live(userID: "@bob:example.org"))
    }

    @Test
    func showLocationOpensAnEndedLiveShareAtItsLastPosition() {
        let (viewModel, _, _) = makeViewModel()

        viewModel.context.send(viewAction: .showLocation(liveItem(isLive: false)))

        #expect(viewModel.context.viewState.bindings.locationMap?.mode == .location(pub, description: nil))
    }

    @Test
    func aLiveBubbleShowsTheSharesLatestPosition() async throws {
        let shares = CurrentValueSubject<[LiveLocationSummary], Never>([])
        let (viewModel, _, _) = makeViewModel(liveLocations: shares)
        let item = liveItem(isLive: true)

        shares.send([.fixture(userID: "@bob:example.org", beaconID: "$beacon", geoURI: park)])

        try await waitUntil { viewModel.context.viewState.liveLocation(for: item)?.geoURI == park }
        #expect(viewModel.context.viewState.liveLocation(for: item)?.isLive == true)
    }

    @Test
    func aLiveBubbleIgnoresTheSendersOtherShares() async throws {
        let shares = CurrentValueSubject<[LiveLocationSummary], Never>([.fixture(userID: "@bob:example.org", beaconID: "$newer", geoURI: park)])
        let (viewModel, _, _) = makeViewModel(liveLocations: shares)
        try await waitUntil { viewModel.context.viewState.liveLocations?.count == 1 }

        let state = viewModel.context.viewState.liveLocation(for: liveItem(isLive: true))

        #expect(state == LiveLocationBubbleState(isLive: false, geoURI: pub, lastUpdate: Date(timeIntervalSince1970: 1_700_000_000)))
    }

    @Test
    func aLiveBubbleEndsWhenItsShareLeaves() async throws {
        let shares = CurrentValueSubject<[LiveLocationSummary], Never>([.fixture(userID: "@bob:example.org", beaconID: "$beacon", geoURI: park)])
        let (viewModel, _, _) = makeViewModel(liveLocations: shares)
        let item = liveItem(isLive: true)
        try await waitUntil { viewModel.context.viewState.liveLocation(for: item)?.geoURI == park }

        shares.send([])

        try await waitUntil { viewModel.context.viewState.liveLocation(for: item)?.isLive == false }
        #expect(viewModel.context.viewState.liveLocation(for: item)?.geoURI == pub, "Falls back to the event's own last position.")
    }

    @Test
    func aLiveBubbleWithoutRoomSharesTrustsItsEvent() {
        let (viewModel, _, _) = makeViewModel()

        let state = viewModel.context.viewState.liveLocation(for: liveItem(isLive: true))

        #expect(state == LiveLocationBubbleState(isLive: true, geoURI: pub, lastUpdate: Date(timeIntervalSince1970: 1_700_000_000)))
    }

    // MARK: - Helpers

    private var pub: GeoURI { GeoURI(latitude: 51.5072, longitude: -0.1276, uncertainty: nil) }
    private var park: GeoURI { GeoURI(latitude: 51.5073, longitude: -0.1657, uncertainty: nil) }

    private func liveItem(isLive: Bool) -> EventItem {
        EventItem.fixture(eventID: "$beacon",
                          body: .liveLocation(LiveLocationBody(isLive: isLive, lastGeoURI: pub,
                                                               lastUpdate: Date(timeIntervalSince1970: 1_700_000_000),
                                                               senderID: "@bob:example.org")))
    }

    private func makeViewModel(liveLocations: CurrentValueSubject<[LiveLocationSummary], Never>? = nil)
        -> (ChatScreenViewModel, TimelineProxyMock, PassthroughSubject<[ElementXWatch.TimelineItem], Never>) {
        let items = PassthroughSubject<[ElementXWatch.TimelineItem], Never>()
        let proxy = TimelineProxyMock()
        proxy.itemsPublisher = items.eraseToAnyPublisher()
        proxy.paginateBackwardsReturnValue = .success(false)
        let roomLocationProxy = liveLocations.map { liveLocations in
            let roomLocationProxy = RoomLocationProxyMock()
            roomLocationProxy.liveLocationsPublisher = liveLocations.eraseToAnyPublisher()
            return roomLocationProxy
        }
        let viewModel = ChatScreenViewModel(roomName: "Alice", isDirect: true, timelineProxy: proxy, roomLocationProxy: roomLocationProxy)
        return (viewModel, proxy, items)
    }
}
