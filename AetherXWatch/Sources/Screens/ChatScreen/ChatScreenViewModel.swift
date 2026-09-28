//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation

typealias ChatScreenViewModelType = StateStoreViewModelV2<ChatScreenViewState, ChatScreenViewAction>

final class ChatScreenViewModel: ChatScreenViewModelType, ChatScreenViewModelProtocol {
    private let timelineProxy: TimelineProxyProtocol
    private let liveLocationService: LiveLocationServiceProtocol
    private let voiceMessagePlayer: VoiceMessagePlayerProtocol
    private let now: () -> Date
    private var hasAppeared = false
    private var lastReadItemID: String?

    /// - Parameter ticks: Re-evaluates live shares' expiry; `now` gives the time at each tick.
    init(roomID: String,
         roomName: String,
         isDirect: Bool,
         timelineProxy: TimelineProxyProtocol,
         roomLocationProxy: RoomLocationProxyProtocol?,
         liveLocationService: LiveLocationServiceProtocol,
         voiceMessagePlayer: VoiceMessagePlayerProtocol,
         now: @escaping () -> Date = Date.init,
         ticks: AnyPublisher<Void, Never> = LiveLocationExpiry.ticks) {
        self.timelineProxy = timelineProxy
        self.liveLocationService = liveLocationService
        self.voiceMessagePlayer = voiceMessagePlayer
        self.now = now
        super.init(initialViewState: ChatScreenViewState(roomName: roomName, showsSenderNames: !isDirect, now: now()))

        timelineProxy.itemsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in self?.update(items) }
            .store(in: &cancellables)

        roomLocationProxy?.liveLocationsPublisher
            // The list starts empty before the room's first update (only sent once there are shares), and an empty
            // list would end every live bubble; until then the bubbles trust their events.
            .drop { $0.isEmpty }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] liveLocations in self?.update(liveLocations) }
            .store(in: &cancellables)

        liveLocationService.statePublisher
            .map { liveState in
                guard case .sharing(roomID, let endsAt, let isPaused) = liveState else { return nil }
                return LiveShareBanner(endsAt: endsAt, isPaused: isPaused)
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] banner in self?.state.liveShare = banner }
            .store(in: &cancellables)

        ticks
            .sink { [weak self] in self?.refreshNow() }
            .store(in: &cancellables)

        voiceMessagePlayer.statePublisher
            .removeDuplicates()
            .sink { [weak self] playback in self?.state.voicePlayback = playback }
            .store(in: &cancellables)
    }

    override func process(viewAction: ChatScreenViewAction) {
        switch viewAction {
        case .appear:
            appear()
        case .disappear:
            voiceMessagePlayer.stop()
        case .paginateBackwards:
            paginateBackwards()
        case .send(let text):
            send(text)
        case .showActions(let item):
            state.bindings.actionsItem = item
        case .showLocation(let item):
            showLocation(item)
        case .showAttachments:
            // The recorder and the players share one audio session, so only one of them may use it at a time.
            voiceMessagePlayer.stop()
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
        case .stopLiveLocation:
            Task { await liveLocationService.stop() }
        case .toggleVoicePlayback(let item):
            toggleVoicePlayback(item)
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
        refreshNow()
        state.items = items.filter(\.isVisible)

        // Keep the read receipt current while the chat is open.
        if let last = state.items.last, last.id != lastReadItemID {
            lastReadItemID = last.id
            Task { await timelineProxy.markAsRead() }
        }
    }

    private func update(_ liveLocations: [LiveLocationSummary]) {
        refreshNow()
        state.liveLocations = liveLocations
    }

    private func refreshNow() {
        state.now = now()
    }

    private func showLocation(_ item: EventItem) {
        refreshNow()
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
                return .live(userID: body.senderID, initial: liveLocation.geoURI, endDate: liveLocation.endDate)
            }
            return liveLocation.geoURI.map { .location($0, description: nil) }
        default:
            return nil
        }
    }

    private func toggleVoicePlayback(_ item: EventItem) {
        guard case .voice(let voice) = item.body else { return }
        if case .playing = state.voicePlayback(for: item) {
            voiceMessagePlayer.pause()
        } else {
            Task { await voiceMessagePlayer.play(id: item.id, source: voice.source) }
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
