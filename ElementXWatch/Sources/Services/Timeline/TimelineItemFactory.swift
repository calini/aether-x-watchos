//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

/// Maps SDK timeline items to the watch's display models.
enum TimelineItemFactory {
    /// MSC3246 amplitudes run 0…1024 (iOS's `EstimatedWaveform.dataRange`, the SDK's `UnstableAmplitude::MAX`).
    private static let voiceWaveformMaximum: Float = 1024

    static func makeItem(from item: MatrixRustSDK.TimelineItem, ownUserID: String) -> TimelineItem {
        let id = item.uniqueId().id

        if let event = item.asEvent() {
            guard let body = body(for: event.content, senderID: event.sender) else { return TimelineItem(id: id, kind: .hidden) }
            return TimelineItem(id: id, kind: .event(makeEventItem(event, body: body, ownUserID: ownUserID)))
        }

        switch item.asVirtual() {
        case .dateDivider(let timestamp):
            return TimelineItem(id: id, kind: .dateDivider(Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)))
        case .readMarker:
            return TimelineItem(id: id, kind: .readMarker)
        case .timelineStart:
            return TimelineItem(id: id, kind: .timelineStart)
        case nil:
            return TimelineItem(id: id, kind: .hidden)
        }
    }

    static func body(for content: TimelineItemContent, senderID: String = "") -> TimelineItemBody? {
        guard case .msgLike(let msgLike) = content else { return nil }

        switch msgLike.kind {
        case .message(let message):
            switch message.msgType {
            case .text(let text):
                return .text(MessageFormatter.attributedString(from: text.body, formatted: text.formatted))
            case .emote(let emote):
                return .emote(MessageFormatter.attributedString(from: emote.body, formatted: emote.formatted))
            case .notice(let notice):
                return .notice(MessageFormatter.attributedString(from: notice.body, formatted: notice.formatted))
            case .image(let image):
                return .image(ImageBody(caption: image.caption,
                                         source: MediaSourceProxy(source: image.source),
                                         thumbnailSource: image.info?.thumbnailSource.map(MediaSourceProxy.init),
                                         aspectRatio: aspectRatio(width: image.info?.width, height: image.info?.height)))
            case .location(let location):
                return .location(locationBody(from: location))
            case .audio(let audio) where audio.voice != nil:
                return .voice(voiceBody(from: audio))
            default:
                return .unsupported(RoomSummaryPreview.text(for: content) ?? WatchStrings.unsupportedMessage)
            }
        case .sticker(_, let info, let source):
            return .image(ImageBody(caption: nil,
                                     source: MediaSourceProxy(source: source),
                                     thumbnailSource: info.thumbnailSource.map(MediaSourceProxy.init),
                                     aspectRatio: aspectRatio(width: info.width, height: info.height)))
        case .redacted:
            return .redacted
        case .unableToDecrypt:
            return .undecryptable
        case .liveLocation(let liveLocation):
            return .liveLocation(liveLocationBody(from: liveLocation, senderID: senderID))
        case .poll:
            return .unsupported(RoomSummaryPreview.text(for: content) ?? WatchStrings.unsupportedMessage)
        case .other:
            return nil
        }
    }

    static func locationBody(from content: LocationContent) -> LocationBody {
        LocationBody(geoURI: GeoURI(string: content.geoUri), description: content.description, body: content.body)
    }

    static func voiceBody(from content: AudioMessageContent) -> VoiceBody {
        VoiceBody(duration: content.audio?.duration ?? content.info?.duration ?? 0,
                  waveform: (content.audio?.waveform ?? []).map { min(Float($0) / voiceWaveformMaximum, 1) },
                  source: MediaSourceProxy(source: content.source))
    }

    static func liveLocationBody(from content: LiveLocationContent, senderID: String) -> LiveLocationBody {
        let lastLocation = content.locations.last
        return LiveLocationBody(isLive: content.isLive,
                                 lastGeoURI: lastLocation.flatMap { GeoURI(string: $0.geoUri) },
                                 lastUpdate: lastLocation.map { Date(timeIntervalSince1970: TimeInterval($0.ts) / 1000) },
                                 endDate: liveLocationEndDate(of: content),
                                 senderID: senderID)
    }

    /// Saturates: the timeout comes from other people's events, and an overflowing `+` would trap.
    private static func liveLocationEndDate(of content: LiveLocationContent) -> Date {
        let (end, didOverflow) = content.ts.addingReportingOverflow(content.timeoutMs)
        return didOverflow ? .distantFuture : Date(timeIntervalSince1970: TimeInterval(end) / 1000)
    }

    static func isEdited(_ content: TimelineItemContent) -> Bool {
        guard case .msgLike(let msgLike) = content, case .message(let message) = msgLike.kind else { return false }
        return message.isEdited
    }

    static func reactions(from reactions: [Reaction], ownUserID: String) -> [ReactionSummary] {
        reactions.map { reaction in
            ReactionSummary(key: reaction.key,
                             count: reaction.senders.count,
                             isHighlighted: reaction.senders.contains { $0.senderId == ownUserID })
        }
    }

    static func sendState(from state: EventSendState?) -> SendState {
        switch state {
        case nil, .sent: .sent
        case .notSentYet: .sending
        case .sendingFailed: .failed
        }
    }

    private static func makeEventItem(_ event: EventTimelineItem, body: TimelineItemBody, ownUserID: String) -> EventItem {
        let eventID: String? = if case .eventId(let id) = event.eventOrTransactionId { id } else { nil }
        return EventItem(itemID: event.eventOrTransactionId,
                          eventID: eventID,
                          senderID: event.sender,
                          senderName: RoomSummaryPreview.displayName(from: event.senderProfile) ?? event.sender,
                          isOwn: event.isOwn,
                          date: Date(timeIntervalSince1970: TimeInterval(event.timestamp) / 1000),
                          body: body,
                          replyTo: replyPreview(for: event.content),
                          reactions: reactions(from: event.reactions, ownUserID: ownUserID),
                          isEdited: isEdited(event.content),
                          sendState: sendState(from: event.localSendState),
                          canBeRepliedTo: event.canBeRepliedTo)
    }

    private static func replyPreview(for content: TimelineItemContent) -> ReplyPreview? {
        guard case .msgLike(let msgLike) = content, let inReplyTo = msgLike.inReplyTo else { return nil }
        guard case .ready(let repliedContent, let sender, let senderProfile, _, _) = inReplyTo.event() else {
            return ReplyPreview(senderName: "", text: "…")
        }
        return ReplyPreview(senderName: RoomSummaryPreview.displayName(from: senderProfile) ?? sender,
                             text: RoomSummaryPreview.text(for: repliedContent) ?? WatchStrings.unsupportedMessage)
    }

    private static func aspectRatio(width: UInt64?, height: UInt64?) -> Double? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return Double(width) / Double(height)
    }
}
