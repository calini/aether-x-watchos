//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct PasswordLoginScreen: View {
    @Bindable var context: PasswordLoginScreenViewModel.Context

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(context.viewState.serverName).font(.footnote).foregroundStyle(Color.compound.textSecondary)
                TextField(WatchStrings.usernamePrompt, text: $context.username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField(WatchStrings.passwordPrompt, text: $context.password)
                    .textContentType(.password)
                if let error = context.viewState.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(Color.compound.textCriticalPrimary)
                }
                if context.viewState.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Button(WatchStrings.signInAction) { context.send(viewAction: .signIn) }
                        .buttonStyle(.fullWidth)
                        .disabled(!context.viewState.canSignIn)
                        .tint(Color.compound.bgAccentRest)
                }
            }
            .disabled(context.viewState.isLoading)
        }
        .navigationTitle(WatchStrings.signInMethodTitle)
        // Backing out mid-sign-in would reset the login client the request is still using.
        .navigationBarBackButtonHidden(context.viewState.isLoading)
    }
}

// MARK: - Previews

struct PasswordLoginScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { PasswordLoginScreen(context: makeViewModel().context) }
            .previewDisplayName("Empty")
        NavigationStack { PasswordLoginScreen(context: makeViewModel(isLoading: true).context) }
            .previewDisplayName("Signing in")
        NavigationStack { PasswordLoginScreen(context: makeViewModel(error: WatchStrings.wrongCredentials).context) }
            .previewDisplayName("Error")
    }

    static func makeViewModel(isLoading: Bool = false, error: String? = nil) -> PasswordLoginScreenViewModel {
        let viewModel = PasswordLoginScreenViewModel(serverName: "matrix.org", authenticationService: AuthenticationServiceMock())
        viewModel.state.bindings.username = "alice"
        viewModel.state.isLoading = isLoading
        viewModel.state.errorMessage = error
        return viewModel
    }
}
