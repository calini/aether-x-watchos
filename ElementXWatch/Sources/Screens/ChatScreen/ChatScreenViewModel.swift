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

    init(roomName: String, isDirect: Bool, timelineProxy: TimelineProxyProtocol, roomLocationProxy: RoomLocationProxyProtocol?) {
        self.timelineProxy = timelineProxy
        super.init(initialViewState: ChatScreenViewState(roomName: roomName, showsSenderNames: !isDirect))

        timelineProxy.itemsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in self?.update(items) }
            .store(in: &cancellables)

        roomLocationProxy?.liveLocationsPublisher
            // The list starts empty before the room's first update (only sent once there are shares), and an empty
            // list would end every live bubble; until then the bubbles trust their events.
            .drop { $0.isEmpty }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] liveLocations in self?.state.liveLocations = liveLocations }
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
        case .showLocation(let item):
            showLocation(item)
        case .showAttachments:
            state.bindings.attachments = AttachmentsPresentation()
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

    /// Called once something has been shared from the (+) sheet.
    func dismissAttachments() {
        state.bindings.attachments = nil
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

    private func showLocation(_ item: EventItem) {
        guard let mode = locationMapMode(for: item) else { return }
        state.bindings.locationMap = LocationMapPresentation(mode: mode)
    }

    /// A running live share follows its sender; an ended one shows where it stopped.
    private func locationMapMode(for item: EventItem) -> LocationMapScreenMode? {
        switch item.body {
        case .location(let body):
            return body.geoURI.map { .location($0, description: body.description) }
        case .liveLocation(let body):
            guard let liveLocation = state.liveLocation(for: item) else { return nil }
            if liveLocation.isLive {
                return .live(userID: body.senderID, initial: liveLocation.geoURI)
            }
            return liveLocation.geoURI.map { .location($0, description: nil) }
        default:
            return nil
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
