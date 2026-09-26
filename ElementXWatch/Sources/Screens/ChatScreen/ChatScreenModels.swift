//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

struct ChatScreenViewState: BindableState {
    let roomName: String
    /// Groups show sender names above messages; DMs don't.
    let showsSenderNames: Bool
    var items: [TimelineItem] = []
    var isPaginating = false
    /// Set when the last back-pagination request failed; cleared as soon as a new one starts.
    var paginationFailed = false
    /// Bumped after every successful pagination that didn't reach the start, so the spinner's
    /// `.task(id:)` re-runs even when a page added no new visible item (e.g. all hidden state events).
    var paginationRequestID = 0
    var reachedStart = false
    var replyingTo: EventItem?
    /// A message that failed to send, kept around so it can be retried without retyping it.
    var draft: ChatDraft?
    /// The room's running live shares; `nil` when they can't be observed or haven't loaded, so live bubbles trust their event.
    var liveLocations: [LiveLocationSummary]?
    var bindings = ChatScreenBindings()

    /// A live share's bubble: its event merged with the room's latest data for the same share.
    func liveLocation(for item: EventItem) -> LiveLocationBubbleState? {
        guard case .liveLocation(let body) = item.body else { return nil }
        guard let liveLocations else {
            return LiveLocationBubbleState(isLive: body.isLive, geoURI: body.lastGeoURI, lastUpdate: body.lastUpdate)
        }

        // Matching the beacon too keeps an older share's bubble from following the sender's newer one.
        let share = liveLocations.first { $0.userID == body.senderID && (item.eventID == nil || $0.beaconID == item.eventID) }
        return LiveLocationBubbleState(isLive: body.isLive && share != nil,
                                       geoURI: share?.lastGeoURI ?? body.lastGeoURI,
                                       lastUpdate: share?.lastUpdate ?? body.lastUpdate)
    }
}

struct LiveLocationBubbleState: Equatable {
    let isLive: Bool
    let geoURI: GeoURI?
    let lastUpdate: Date?
}

/// Each presentation gets its own ID, so reopening the same location shows a fresh map.
struct LocationMapPresentation: Identifiable {
    let id = UUID()
    let mode: LocationMapScreenMode
}

/// Each presentation gets its own ID, so reopening the (+) sheet starts afresh.
struct AttachmentsPresentation: Identifiable {
    let id = UUID()
}

/// A message that failed to enqueue, remembered so `.retryDraft` can resend the same text.
struct ChatDraft: Equatable {
    let text: String
    let replyingTo: EventItem?
}

struct ChatScreenBindings {
    /// The message whose actions (reactions, reply) are showing.
    var actionsItem: EventItem?
    var errorMessage: String?
    var locationMap: LocationMapPresentation?
    var attachments: AttachmentsPresentation?
}

enum ChatScreenViewAction {
    case appear
    case paginateBackwards
    case send(String)
    case showActions(EventItem)
    case showLocation(EventItem)
    case showAttachments
    case reply(EventItem)
    case cancelReply
    case react(key: String, item: EventItem)
    case retry(EventItem)
    case retryDraft
    case cancelDraft
    case dismissError
}
