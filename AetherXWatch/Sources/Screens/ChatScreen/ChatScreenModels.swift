//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
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
    /// This device's live share in this room, if one is running.
    var liveShare: LiveShareBanner?
    /// The session player's state; only the message it names shows it (`voicePlayback(for:)`).
    var voicePlayback = VoicePlaybackState.idle
    /// Refreshed on a periodic tick, so a share whose sender vanished without stopping it still reads as ended.
    var now: Date
    var bindings = ChatScreenBindings()

    /// A live share's bubble: its event merged with the room's latest data for the same share.
    func liveLocation(for item: EventItem) -> LiveLocationBubbleState? {
        guard case .liveLocation(let body) = item.body else { return nil }
        guard let liveLocations else {
            return LiveLocationBubbleState(isLive: body.isLive && now < body.endDate, geoURI: body.lastGeoURI,
                                           lastUpdate: body.lastUpdate, endDate: body.endDate)
        }

        // Matching the beacon too keeps an older share's bubble from following the sender's newer one.
        let share = liveLocations.first { $0.userID == body.senderID && (item.eventID == nil || $0.beaconID == item.eventID) }
        let endDate = share?.endDate ?? body.endDate
        return LiveLocationBubbleState(isLive: body.isLive && share != nil && now < endDate,
                                       geoURI: share?.lastGeoURI ?? body.lastGeoURI,
                                       lastUpdate: share?.lastUpdate ?? body.lastUpdate,
                                       endDate: endDate)
    }

    func voicePlayback(for item: EventItem) -> VoicePlaybackState {
        voicePlayback.id == item.id ? voicePlayback : .idle
    }

    /// Own running live bubbles offer Stop while this device shares in this room.
    func canStopLiveLocation(from item: EventItem) -> Bool {
        item.isOwn && liveShare != nil && liveLocation(for: item)?.isLive == true
    }
}

struct LiveLocationBubbleState: Equatable {
    let isLive: Bool
    let geoURI: GeoURI?
    let lastUpdate: Date?
    let endDate: Date
}

struct LiveShareBanner: Equatable {
    let endsAt: Date
    let isPaused: Bool

    /// Rounded up, so the pill reads "1 min left" until the share actually ends.
    func minutesLeft(at date: Date) -> Int {
        let secondsLeft = endsAt.timeIntervalSince(date)
        return secondsLeft > 0 ? Int((secondsLeft / 60).rounded(.up)) : 0
    }

    /// The share's minute boundary at or before `date`, so a countdown ticking every minute from it drops
    /// exactly as each minute runs out.
    func countdownStart(at date: Date) -> Date {
        endsAt.addingTimeInterval(-60 * Double(minutesLeft(at: date)))
    }
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
    case disappear
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
    case stopLiveLocation
    case toggleVoicePlayback(EventItem)
}
