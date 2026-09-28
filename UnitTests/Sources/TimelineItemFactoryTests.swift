//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import AetherXWatch
import Foundation
import MatrixRustSDK
import Testing

struct TimelineItemFactoryTests {
    @Test
    func textLikeMessagesMap() {
        #expect(TimelineItemFactory.body(for: textContent("hi")) == .text(AttributedString("hi")))
        #expect(TimelineItemFactory.body(for: messageContent(.emote(content: EmoteMessageContent(body: "waves", formatted: nil)))) == .emote(AttributedString("waves")))
        #expect(TimelineItemFactory.body(for: messageContent(.notice(content: NoticeMessageContent(body: "bot", formatted: nil)))) == .notice(AttributedString("bot")))
    }

    @Test
    func specialStatesMap() {
        #expect(TimelineItemFactory.body(for: msgLike(.redacted)) == .redacted)
        #expect(TimelineItemFactory.body(for: msgLike(.unableToDecrypt(msg: .unknown))) == .undecryptable)
    }

    @Test
    func imagesMap() throws {
        let source = try MediaSource.fromUrl(url: "mxc://example.org/abc")
        let image = ImageMessageContent(filename: "a.jpg", caption: "Look", formattedCaption: nil, source: source,
                                         info: ImageInfo(height: 100, width: 200, mimetype: "image/jpeg", size: nil, thumbnailInfo: nil,
                                                          thumbnailSource: nil, blurhash: nil, isAnimated: false))

        let body = TimelineItemFactory.body(for: messageContent(.image(content: image)))

        guard case .image(let imageBody) = body else { Issue.record("Expected an image"); return }
        #expect(imageBody.caption == "Look")
        #expect(imageBody.source.url == "mxc://example.org/abc")
        #expect(imageBody.aspectRatio == 2)
    }

    @Test
    func unsupportedMessagesShowAPlaceholder() {
        #expect(TimelineItemFactory.body(for: msgLike(.poll(question: "Lunch?", kind: .undisclosed, maxSelections: 1, answers: [], votes: [:], endTime: nil, hasBeenEdited: false)))
            == .unsupported("📊 Lunch?"))
    }

    @Test
    func stateEventsAreHidden() {
        #expect(TimelineItemFactory.body(for: .profileChange(displayName: "B", prevDisplayName: "A", avatarUrl: nil, prevAvatarUrl: nil)) == nil)
    }

    @Test
    func editsAreDetected() {
        #expect(TimelineItemFactory.isEdited(textContent("x", isEdited: true)))
        #expect(!TimelineItemFactory.isEdited(textContent("x")))
    }

    @Test
    func reactionsAreCountedAndHighlightedForOwn() {
        let reactions = [
            Reaction(key: "👍", senders: [.init(senderId: "@me:x", timestamp: 1), .init(senderId: "@bob:x", timestamp: 2)]),
            Reaction(key: "❤️", senders: [.init(senderId: "@bob:x", timestamp: 3)])
        ]

        let summaries = TimelineItemFactory.reactions(from: reactions, ownUserID: "@me:x")

        #expect(summaries == [.init(key: "👍", count: 2, isHighlighted: true), .init(key: "❤️", count: 1, isHighlighted: false)])
    }

    @Test
    func sendStatesMap() {
        #expect(TimelineItemFactory.sendState(from: nil) == .sent)
        #expect(TimelineItemFactory.sendState(from: .notSentYet(progress: nil)) == .sending)
        #expect(TimelineItemFactory.sendState(from: .sent(eventId: "$e")) == .sent)
    }
}
