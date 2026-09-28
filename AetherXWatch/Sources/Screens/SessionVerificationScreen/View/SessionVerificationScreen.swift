//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct SessionVerificationScreen: View {
    let context: SessionVerificationScreenViewModel.Context

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                content
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(WatchStrings.verifyTitle)
    }

    @ViewBuilder
    private var content: some View {
        switch context.viewState.step {
        case .intro:
            Text(WatchStrings.verifyIntro).multilineTextAlignment(.center)
            Button(WatchStrings.verifyStart) { context.send(viewAction: .start) }.tint(Color.compound.bgAccentRest)
            Button(WatchStrings.notNow) { context.send(viewAction: .dismiss) }
        case .waitingForAcceptance, .startingSas:
            ProgressView()
            Text(WatchStrings.verifyWaiting).multilineTextAlignment(.center)
            Button(WatchStrings.cancel) { context.send(viewAction: .cancel) }
        case .comparing(let data):
            Text(WatchStrings.verifyCompare).font(.headline).multilineTextAlignment(.center)
            dataView(data)
            Button(WatchStrings.theyMatch) { context.send(viewAction: .match) }.tint(Color.compound.bgAccentRest)
            Button(WatchStrings.theyDontMatch, role: .destructive) { context.send(viewAction: .noMatch) }
        case .confirming:
            ProgressView()
            Button(WatchStrings.cancel) { context.send(viewAction: .cancel) }
        case .verified:
            Text(WatchStrings.verificationSucceeded).multilineTextAlignment(.center)
            Button(WatchStrings.done) { context.send(viewAction: .dismiss) }
        case .declined:
            Text(WatchStrings.verificationDeclined).multilineTextAlignment(.center)
            Button(WatchStrings.done) { context.send(viewAction: .dismiss) }
        case .cancelled, .failed:
            Text(context.viewState.step == .failed ? WatchStrings.verificationFailed : WatchStrings.verificationCancelled)
                .multilineTextAlignment(.center)
            Button(WatchStrings.tryAgain) { context.send(viewAction: .tryAgain) }
            Button(WatchStrings.notNow) { context.send(viewAction: .dismiss) }
        }
    }

    @ViewBuilder
    private func dataView(_ data: VerificationData) -> some View {
        switch data {
        case .emojis(let emojis):
            ForEach(emojis) { emoji in
                HStack {
                    Text(emoji.symbol).font(.title3)
                    Text(emoji.description).font(.footnote)
                    Spacer()
                }
            }
        case .decimals(let values):
            Text(values.map(String.init).joined(separator: " ")).font(.title3.monospacedDigit())
        }
    }
}

// MARK: - Previews

struct SessionVerificationScreen_Previews: PreviewProvider {
    static let emojis = ["🐶 Dog", "🔑 Key", "🎸 Guitar", "🌵 Cactus", "⚓️ Anchor", "🍕 Pizza", "🚀 Rocket"].map {
        VerificationEmoji(symbol: String($0.prefix(1)), description: String($0.dropFirst(2)))
    }

    static let steps: [(String, SessionVerificationStep)] = [
        ("Intro", .intro),
        ("Waiting", .waitingForAcceptance),
        ("Emojis", .comparing(.emojis(emojis))),
        ("Decimals", .comparing(.decimals([1234, 5678, 9012]))),
        ("Confirming", .confirming),
        ("Verified", .verified),
        ("Declined", .declined),
        ("Cancelled", .cancelled),
        ("Failed", .failed)
    ]

    static var previews: some View {
        ForEach(steps, id: \.0) { name, step in
            NavigationStack { SessionVerificationScreen(context: makeViewModel(step).context) }
                .previewDisplayName(name)
        }
    }

    static func makeViewModel(_ step: SessionVerificationStep) -> SessionVerificationScreenViewModel {
        let viewModel = SessionVerificationScreenViewModel(controllerLoader: { nil })
        viewModel.state.step = step
        return viewModel
    }
}
