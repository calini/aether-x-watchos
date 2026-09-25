//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

struct ChatScreenViewState: BindableState {
    let roomName: String
    /// Groups show sender names above messages; DMs don't.
    let showsSenderNames: Bool
    var items: [TimelineItem] = []
    var isPaginating = false
    var reachedStart = false
    var replyingTo: EventItem?
    var bindings = ChatScreenBindings()
}

struct ChatScreenBindings {
    /// The message whose actions (reactions, reply) are showing.
    var actionsItem: EventItem?
    var errorMessage: String?
}

enum ChatScreenViewAction {
    case appear
    case paginateBackwards
    case send(String)
    case showActions(EventItem)
    case reply(EventItem)
    case cancelReply
    case react(key: String, item: EventItem)
    case retry(EventItem)
    case dismissError
}
