//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

@testable import AetherXWatch
import Foundation
import MatrixRustSDK
import Testing

struct RoomSummaryPreviewTests {
    @Test
    func directMessagesHaveNoSenderPrefix() {
        #expect(RoomSummaryPreview.text(for: remoteLatestEvent(textContent("Hi!")), isDirect: true) == "Hi!")
    }

    @Test
    func groupMessagesArePrefixedWithTheSender() {
        #expect(RoomSummaryPreview.text(for: remoteLatestEvent(textContent("Hi!")), isDirect: false) == "Bob: Hi!")
    }

    @Test
    func groupMessagesFallBackToTheUserID() {
        #expect(RoomSummaryPreview.text(for: remoteLatestEvent(textContent("Hi!"), name: nil), isDirect: false) == "@bob:example.org: Hi!")
    }

    @Test
    func ownMessagesArePrefixedWithYou() {
        #expect(RoomSummaryPreview.text(for: remoteLatestEvent(textContent("Hi!"), isOwn: true), isDirect: true) == "You: Hi!")
    }

    @Test
    func specialContentHasReadablePreviews() {
        #expect(RoomSummaryPreview.text(for: msgLike(.redacted)) == WatchStrings.messageDeleted)
        #expect(RoomSummaryPreview.text(for: msgLike(.unableToDecrypt(msg: .unknown))) == WatchStrings.waitingForMessage)
        #expect(RoomSummaryPreview.text(for: messageContent(.emote(content: EmoteMessageContent(body: "waves", formatted: nil)))) == "* waves")
    }

    @Test
    func stateEventsAndEmptyRoomsHaveNoPreview() {
        #expect(RoomSummaryPreview.text(for: LatestEventValue.none, isDirect: true) == nil)
        #expect(RoomSummaryPreview.text(for: .profileChange(displayName: "B", prevDisplayName: "A", avatarUrl: nil, prevAvatarUrl: nil)) == nil)
    }

    @Test
    func dateComesFromTheTimestamp() {
        #expect(RoomSummaryPreview.date(for: remoteLatestEvent(textContent("x"), timestamp: 1_700_000_000_000)) == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(RoomSummaryPreview.date(for: .none) == nil)
    }
}
