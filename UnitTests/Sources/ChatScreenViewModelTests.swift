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
    }

    @Test
    func failedMessagesCanBeRetried() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        proxy.retrySendReturnValue = .failure(.sdkError("still offline"))
        let failed = EventItem.fixture(eventID: nil, sendState: .failed)

        viewModel.context.send(viewAction: .retry(failed))

        try await waitUntil { proxy.retrySendCallsCount == 1 }
        #expect(proxy.retrySendReceivedItemID == failed.itemID)
        try await waitUntil { viewModel.context.viewState.bindings.errorMessage == WatchStrings.sendFailed }
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

    // MARK: - Helpers

    private func makeViewModel() -> (ChatScreenViewModel, TimelineProxyMock, PassthroughSubject<[ElementXWatch.TimelineItem], Never>) {
        let items = PassthroughSubject<[ElementXWatch.TimelineItem], Never>()
        let proxy = TimelineProxyMock()
        proxy.itemsPublisher = items.eraseToAnyPublisher()
        proxy.paginateBackwardsReturnValue = .success(false)
        let viewModel = ChatScreenViewModel(roomName: "Alice", isDirect: true, timelineProxy: proxy)
        return (viewModel, proxy, items)
    }
}
