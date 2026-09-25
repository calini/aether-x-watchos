//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation

typealias ChatScreenViewModelType = StateStoreViewModelV2<ChatScreenViewState, ChatScreenViewAction>

final class ChatScreenViewModel: ChatScreenViewModelType, ChatScreenViewModelProtocol {
    private let timelineProxy: TimelineProxyProtocol
    private var hasAppeared = false
    private var lastReadItemID: String?

    init(roomName: String, isDirect: Bool, timelineProxy: TimelineProxyProtocol) {
        self.timelineProxy = timelineProxy
        super.init(initialViewState: ChatScreenViewState(roomName: roomName, showsSenderNames: !isDirect))

        timelineProxy.itemsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in self?.update(items) }
            .store(in: &cancellables)
    }

    override func process(viewAction: ChatScreenViewAction) {
        switch viewAction {
        case .appear:
            appear()
        case .paginateBackwards:
            paginateBackwards()
        case .send(let text):
            send(text)
        case .showActions(let item):
            state.bindings.actionsItem = item
        case .reply(let item):
            state.bindings.actionsItem = nil
            state.replyingTo = item
        case .cancelReply:
            state.replyingTo = nil
        case .react(let key, let item):
            state.bindings.actionsItem = nil
            Task { _ = await timelineProxy.toggleReaction(key, to: item.itemID) }
        case .retry(let item):
            retry(item)
        case .retryDraft:
            retryDraft()
        case .cancelDraft:
            state.draft = nil
            state.bindings.errorMessage = nil
        case .dismissError:
            state.bindings.errorMessage = nil
        }
    }

    private func appear() {
        guard !hasAppeared else { return }
        hasAppeared = true
        Task {
            await timelineProxy.subscribe()
            await timelineProxy.markAsRead()
        }
    }

    private func update(_ items: [TimelineItem]) {
        state.items = items.filter(\.isVisible)

        // Keep the read receipt current while the chat is open.
        if let last = state.items.last, last.id != lastReadItemID {
            lastReadItemID = last.id
            Task { await timelineProxy.markAsRead() }
        }
    }

    private func paginateBackwards() {
        guard !state.isPaginating, !state.reachedStart else { return }
        state.isPaginating = true
        state.paginationFailed = false
        Task {
            let result = await timelineProxy.paginateBackwards()
            state.isPaginating = false
            switch result {
            case .success(let reachedStart):
                state.reachedStart = reachedStart
                // Bumping this (rather than keying off the oldest item) re-triggers the spinner's
                // task even when the page added no visible item, e.g. only hidden state events.
                if !reachedStart {
                    state.paginationRequestID += 1
                }
            case .failure:
                state.paginationFailed = true
            }
        }
    }

    private func send(_ text: String) {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        let replyTarget = state.replyingTo
        state.replyingTo = nil
        Task {
            if case .failure = await timelineProxy.send(message: message, inReplyTo: replyTarget?.eventID) {
                // No local echo exists for a message that never enqueued, so the text would
                // otherwise be lost; keep it as a draft the user can retry without retyping it.
                state.replyingTo = replyTarget
                state.draft = ChatDraft(text: message, replyingTo: replyTarget)
                state.bindings.errorMessage = WatchStrings.sendFailed
            }
        }
    }

    private func retry(_ item: EventItem) {
        Task {
            if case .failure = await timelineProxy.retrySend(item.itemID) {
                state.bindings.errorMessage = WatchStrings.resendFailed
            }
        }
    }

    private func retryDraft() {
        guard let draft = state.draft else { return }
        Task {
            if case .failure = await timelineProxy.send(message: draft.text, inReplyTo: draft.replyingTo?.eventID) {
                state.bindings.errorMessage = WatchStrings.sendFailed
            } else {
                state.draft = nil
                state.replyingTo = nil
            }
        }
    }
}
