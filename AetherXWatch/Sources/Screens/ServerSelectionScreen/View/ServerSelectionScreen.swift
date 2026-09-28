//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct ServerSelectionScreen: View {
    @Bindable var context: ServerSelectionScreenViewModel.Context

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                TextField(WatchStrings.serverPrompt, text: $context.server)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(context.viewState.isLoading)
                if let error = context.viewState.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(Color.compound.textCriticalPrimary)
                }
                if context.viewState.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Button(WatchStrings.continueAction) { context.send(viewAction: .continue) }
                        .buttonStyle(.fullWidthProminent)
                        .disabled(!context.viewState.canContinue)
                }
            }
        }
        .navigationTitle(WatchStrings.serverTitle)
    }
}

// MARK: - Previews

struct ServerSelectionScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { ServerSelectionScreen(context: makeViewModel().context) }
            .previewDisplayName("Default")
        NavigationStack { ServerSelectionScreen(context: makeViewModel(isLoading: true).context) }
            .previewDisplayName("Loading")
        NavigationStack { ServerSelectionScreen(context: makeViewModel(error: WatchStrings.serverUnreachable).context) }
            .previewDisplayName("Error")
    }

    static func makeViewModel(isLoading: Bool = false, error: String? = nil) -> ServerSelectionScreenViewModel {
        let viewModel = ServerSelectionScreenViewModel(authenticationService: AuthenticationServiceMock())
        viewModel.state.isLoading = isLoading
        if let error {
            viewModel.state.failedServer = viewModel.state.bindings.server
            viewModel.state.failureMessage = error
        }
        return viewModel
    }
}
