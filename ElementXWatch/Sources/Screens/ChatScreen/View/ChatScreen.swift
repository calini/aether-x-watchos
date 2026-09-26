//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

struct ChatScreen: View {
    @Bindable var context: ChatScreenViewModel.Context

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                paginationRow
                ForEach(context.viewState.items) { item in
                    row(for: item)
                }
                composer
            }
        }
        .defaultScrollAnchor(.bottom)
        .navigationTitle(context.viewState.roomName)
        .onAppear { context.send(viewAction: .appear) }
        .sheet(item: $context.actionsItem) { item in
            MessageActionsSheet(item: item,
                                 onReact: { context.send(viewAction: .react(key: $0, item: item)) },
                                 onReply: { context.send(viewAction: .reply(item)) })
        }
        .alert(context.viewState.bindings.errorMessage ?? "", isPresented: isShowingError) {
            if context.viewState.draft != nil {
                Button(WatchStrings.tryAgain) { context.send(viewAction: .retryDraft) }
                Button(WatchStrings.cancel, role: .cancel) { context.send(viewAction: .cancelDraft) }
            } else {
                Button(WatchStrings.ok) { context.send(viewAction: .dismissError) }
            }
        }
    }

    @ViewBuilder
    private func row(for item: TimelineItem) -> some View {
        switch item.kind {
        case .event(let event):
            MessageBubble(item: event,
                          showsSenderName: context.viewState.showsSenderNames,
                          onLongPress: { context.send(viewAction: .showActions(event)) },
                          onRetry: { context.send(viewAction: .retry(event)) })
        case .dateDivider(let date):
            Text(date, format: .dateTime.weekday().day().month())
                .font(.caption2)
                .foregroundStyle(Color.compound.textSecondary)
                .frame(maxWidth: .infinity)
        case .readMarker, .timelineStart, .hidden:
            EmptyView()
        }
    }

    /// Loads older messages while the spinner is visible, re-triggering after every successful
    /// non-final page (keyed on a counter, not the oldest item, since a page can add only hidden
    /// state events with no new visible row — `.onAppear` alone would then stall forever).
    @ViewBuilder
    private var paginationRow: some View {
        if !context.viewState.reachedStart {
            if context.viewState.paginationFailed {
                Text(WatchStrings.loadOlderMessages)
                    .font(.caption2)
                    .foregroundStyle(Color.compound.textSecondary)
                    .frame(maxWidth: .infinity)
                    .onTapGesture { context.send(viewAction: .paginateBackwards) }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(WatchStrings.loadingOlder)
                    .task(id: context.viewState.paginationRequestID) {
                        context.send(viewAction: .paginateBackwards)
                    }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 4) {
            if let replyingTo = context.viewState.replyingTo {
                HStack {
                    Text("\(WatchStrings.replyingTo) \(replyingTo.senderName)").font(.caption2).lineLimit(1)
                    Spacer()
                    Button { context.send(viewAction: .cancelReply) } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .accessibilityLabel(WatchStrings.cancel)
                }
            }
            TextFieldLink(prompt: Text(WatchStrings.reply)) {
                Label(WatchStrings.reply, systemImage: "arrowshape.turn.up.left.fill")
            } onSubmit: { text in
                context.send(viewAction: .send(text))
            }
            .buttonStyle(.fullWidth)
        }
        .padding(.top, 4)
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { context.viewState.bindings.errorMessage != nil },
                set: { if !$0 { context.send(viewAction: .dismissError) } })
    }
}

// MARK: - Previews

struct ChatScreen_Previews: PreviewProvider {
    static let items: [TimelineItem] = [
        TimelineItem(id: "d", kind: .dateDivider(.now)),
        makeItem("1", "Are we still on for **Saturday**?", own: false, reactions: [.init(key: "👍", count: 2, isHighlighted: true)]),
        makeItem("2", "Yes! See you at 10", own: true),
        makeItem("3", "Waiting for this message", own: false, body: .undecryptable),
        makeItem("4", "Running late", own: true, sendState: .failed)
    ]

    static var replying: ChatScreenViewModel {
        let viewModel = makeViewModel(isDirect: true)
        viewModel.state.replyingTo = items.compactMap { if case .event(let event) = $0.kind { event } else { nil } }.first
        return viewModel
    }

    static var loadingOlder: ChatScreenViewModel {
        let proxy = TimelineProxyMock()
        proxy.itemsPublisher = Just(items).eraseToAnyPublisher()
        // Never resolves, so the preview settles on the spinner instead of looping forever: the
        // view model bumps `paginationRequestID` (and so re-triggers `.task(id:)`) on every
        // non-final success, which a fixed `.success(false)` would do indefinitely here.
        proxy.paginateBackwardsClosure = {
            try? await Task.sleep(for: .seconds(999))
            return .success(false)
        }
        let viewModel = ChatScreenViewModel(roomName: "Bob", isDirect: true, timelineProxy: proxy)
        viewModel.state.items = items
        viewModel.state.reachedStart = false
        return viewModel
    }

    static var paginationFailed: ChatScreenViewModel {
        let viewModel = makeViewModel(isDirect: true)
        viewModel.state.reachedStart = false
        viewModel.state.paginationFailed = true
        return viewModel
    }

    static var sendingMessage: ChatScreenViewModel {
        let viewModel = makeViewModel(isDirect: true)
        viewModel.state.items = [makeItem("5", "On my way", own: true, sendState: .sending)]
        return viewModel
    }

    static var empty: ChatScreenViewModel {
        let viewModel = makeViewModel(isDirect: true)
        viewModel.state.items = []
        return viewModel
    }

    static var previews: some View {
        NavigationStack { ChatScreen(context: makeViewModel(isDirect: true).context) }
            .previewDisplayName("DM")
        NavigationStack { ChatScreen(context: makeViewModel(isDirect: false).context) }
            .previewDisplayName("Group")
        NavigationStack { ChatScreen(context: replying.context) }
            .previewDisplayName("Replying")
        NavigationStack { ChatScreen(context: loadingOlder.context) }
            .previewDisplayName("Loading older")
        NavigationStack { ChatScreen(context: paginationFailed.context) }
            .previewDisplayName("Pagination failed")
        NavigationStack { ChatScreen(context: sendingMessage.context) }
            .previewDisplayName("Sending")
        NavigationStack { ChatScreen(context: empty.context) }
            .previewDisplayName("Empty")
    }

    static func makeItem(_ id: String, _ text: String, own: Bool, body: TimelineItemBody? = nil,
                          reactions: [ReactionSummary] = [], sendState: SendState = .sent) -> TimelineItem {
        TimelineItem(id: id, kind: .event(EventItem(itemID: .eventId(eventId: "$\(id)"), eventID: "$\(id)", senderID: own ? "@me:x" : "@bob:x",
                                                     senderName: own ? "Me" : "Bob", isOwn: own, date: .now,
                                                     body: body ?? .text(MessageFormatter.attributedString(from: text, formatted: .init(format: .html, body: text))),
                                                     replyTo: nil, reactions: reactions, isEdited: false, sendState: sendState, canBeRepliedTo: true)))
    }

    static func makeViewModel(isDirect: Bool) -> ChatScreenViewModel {
        let proxy = TimelineProxyMock()
        proxy.itemsPublisher = Just(items).eraseToAnyPublisher()
        // Safe default in case a preview's spinner drives a real `.paginateBackwards` via `.task`.
        proxy.paginateBackwardsReturnValue = .success(false)
        let viewModel = ChatScreenViewModel(roomName: isDirect ? "Bob" : "Climbing crew", isDirect: isDirect, timelineProxy: proxy)
        viewModel.state.items = items
        viewModel.state.reachedStart = true
        return viewModel
    }
}
