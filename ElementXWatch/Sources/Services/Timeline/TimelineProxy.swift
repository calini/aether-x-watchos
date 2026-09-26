//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import MatrixRustSDK

enum TimelineProxyError: Error, Equatable {
    case sdkError(String)
}

// sourcery: AutoMockable
protocol TimelineProxyProtocol: AnyObject, Sendable {
    var itemsPublisher: AnyPublisher<[TimelineItem], Never> { get }

    func subscribe() async
    /// Loads older messages. Succeeds with `true` once the start of the room is reached.
    func paginateBackwards() async -> Result<Bool, TimelineProxyError>
    func send(message: String, inReplyTo eventID: String?) async -> Result<Void, TimelineProxyError>
    func sendLocation(_ geoURI: GeoURI, description: String?) async -> Result<Void, TimelineProxyError>
    func toggleReaction(_ key: String, to itemID: EventOrTransactionId) async -> Result<Void, TimelineProxyError>
    func retrySend(_ itemID: EventOrTransactionId) async -> Result<Void, TimelineProxyError>
    func markAsRead() async
}

final class TimelineProxy: TimelineProxyProtocol {
    private static let paginationSize: UInt16 = 20

    private let timeline: Timeline
    private let ownUserID: String
    /// Any send error disables the room's send queue, and `SendHandle.tryResend` only unwedges the item.
    private let enableSendQueue: () -> Void
    private let itemsSubject = CurrentValueSubject<[TimelineItem], Never>([])
    private var items: [TimelineItem] = []
    /// Mirrors `items` 1:1 with the raw SDK items, so a `SendHandle` can be looked up for `retrySend`.
    private var rawItems: [MatrixRustSDK.TimelineItem] = []
    private var listenerHandle: TaskHandle?

    var itemsPublisher: AnyPublisher<[TimelineItem], Never> {
        itemsSubject.eraseToAnyPublisher()
    }

    init(timeline: Timeline, ownUserID: String, enableSendQueue: @escaping () -> Void) {
        self.timeline = timeline
        self.ownUserID = ownUserID
        self.enableSendQueue = enableSendQueue
    }

    deinit {
        listenerHandle?.cancel()
    }

    func subscribe() async {
        guard listenerHandle == nil else { return }
        let ownUserID = ownUserID
        listenerHandle = await timeline.addListener(listener: SDKListener<[TimelineDiff]>.onMainActor { [weak self] diffs in
            guard let self else { return }
            for diff in diffs {
                rawItems.apply(ListDiff(diff) { $0 })
                items.apply(ListDiff(diff) { TimelineItemFactory.makeItem(from: $0, ownUserID: ownUserID) })
            }
            itemsSubject.send(items)
        })
    }

    func paginateBackwards() async -> Result<Bool, TimelineProxyError> {
        do {
            return try await .success(timeline.paginateBackwards(numEvents: Self.paginationSize))
        } catch {
            MXLog.error("Back-pagination failed: \(error)")
            return .failure(.sdkError(error.localizedDescription))
        }
    }

    func send(message: String, inReplyTo eventID: String?) async -> Result<Void, TimelineProxyError> {
        let content = messageEventContentFromMarkdown(md: message)
        do {
            if let eventID {
                _ = try await timeline.sendReply(msg: content, eventId: eventID)
            } else {
                _ = try await timeline.send(msg: content)
            }
            return .success(())
        } catch {
            MXLog.error("Sending a message failed: \(error)")
            return .failure(.sdkError(error.localizedDescription))
        }
    }

    func sendLocation(_ geoURI: GeoURI, description: String?) async -> Result<Void, TimelineProxyError> {
        do {
            let geoURIString = geoURI.string
            try await timeline.sendLocation(body: WatchStrings.locationWasShared(at: geoURIString), geoUri: geoURIString,
                                            description: description, zoomLevel: nil, assetType: .sender, repliedToEventId: nil)
            return .success(())
        } catch {
            // Only the type: the SDK's message could echo the geo URI.
            MXLog.error("Sending a location failed: \(type(of: error))")
            return .failure(.sdkError(error.localizedDescription))
        }
    }

    func toggleReaction(_ key: String, to itemID: EventOrTransactionId) async -> Result<Void, TimelineProxyError> {
        do {
            _ = try await timeline.toggleReaction(itemId: itemID, key: key)
            return .success(())
        } catch {
            MXLog.error("Toggling a reaction failed: \(error)")
            return .failure(.sdkError(error.localizedDescription))
        }
    }

    func retrySend(_ itemID: EventOrTransactionId) async -> Result<Void, TimelineProxyError> {
        // No `Timeline.retrySend` in this SDK build: a wedged local echo is retried through the
        // `SendHandle` exposed on its own `EventTimelineItem` (see `SendHandleProxy` on iOS).
        guard let sendHandle = sendHandle(for: itemID) else {
            MXLog.error("No send handle for \(itemID)")
            return .failure(.sdkError("Message no longer available"))
        }
        return await Self.resend(sendHandle, enablingSendQueueWith: enableSendQueue)
    }

    func markAsRead() async {
        do {
            try await timeline.markAsRead(receiptType: .read)
        } catch {
            MXLog.error("Marking as read failed: \(error)")
        }
    }

    /// Re-enables the room's send queue before unwedging, otherwise the retried echo stays "Sending…" forever.
    static func resend(_ sendHandle: SendHandleProtocol, enablingSendQueueWith enableSendQueue: () -> Void) async -> Result<Void, TimelineProxyError> {
        enableSendQueue()
        do {
            try await sendHandle.tryResend()
            return .success(())
        } catch {
            MXLog.error("Retrying a send failed: \(error)")
            return .failure(.sdkError(error.localizedDescription))
        }
    }

    private func sendHandle(for itemID: EventOrTransactionId) -> SendHandle? {
        rawItems.lazy
            .compactMap { $0.asEvent() }
            .first { $0.eventOrTransactionId == itemID }?
            .lazyProvider.getSendHandle()
    }
}
