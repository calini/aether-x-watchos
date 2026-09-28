//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct SettingsScreen: View {
    @Bindable var context: SettingsScreenViewModel.Context

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading) {
                    Text(context.viewState.displayName ?? context.viewState.userID).font(.headline)
                    Text(context.viewState.userID).font(.footnote).foregroundStyle(Color.compound.textSecondary)
                }
                Label(verificationText, systemImage: context.viewState.verification == .verified ? "checkmark.shield" : "exclamationmark.shield")
                if context.viewState.canVerify {
                    Button(WatchStrings.verifyTitle) { context.send(viewAction: .verifySession) }
                }
            }
            #if DEBUG
            Section {
                Button(audioSupportText) { context.send(viewAction: .checkAudioSupport) }
                    .disabled(context.viewState.audioSupport == .checking)
            }
            #endif
            Section {
                Button(WatchStrings.signOut, role: .destructive) { context.send(viewAction: .signOut) }
            }
        }
        .navigationTitle(WatchStrings.settings)
        .confirmationDialog(WatchStrings.signOutConfirmation, isPresented: $context.isConfirmingSignOut) {
            Button(WatchStrings.signOut, role: .destructive) { context.send(viewAction: .confirmSignOut) }
            Button(WatchStrings.cancel, role: .cancel) { }
        }
    }

    private var verificationText: String {
        switch context.viewState.verification {
        case .verified: WatchStrings.verified
        case .unverified: WatchStrings.unverified
        case .unknown: WatchStrings.verificationUnknown
        }
    }

    private var audioSupportText: String {
        switch context.viewState.audioSupport {
        case .unchecked: WatchStrings.checkAudioSupport
        case .checking: WatchStrings.checkingAudioSupport
        case .supported: WatchStrings.opusSupported
        case .unsupported: WatchStrings.opusUnsupported
        }
    }
}

// MARK: - Previews

struct SettingsScreen_Previews: PreviewProvider {
    static var unverified: SettingsScreenViewModel {
        let viewModel = SettingsScreenViewModel(clientProxy: ClientProxyMock.preview)
        viewModel.state.verification = .unverified
        return viewModel
    }

    static var checkingVerification: SettingsScreenViewModel {
        let viewModel = SettingsScreenViewModel(clientProxy: ClientProxyMock.preview)
        viewModel.state.verification = .unknown
        return viewModel
    }

    static var checkingAudioSupport: SettingsScreenViewModel {
        let viewModel = SettingsScreenViewModel(clientProxy: ClientProxyMock.preview)
        viewModel.state.audioSupport = .checking
        return viewModel
    }

    static var audioSupported: SettingsScreenViewModel {
        let viewModel = SettingsScreenViewModel(clientProxy: ClientProxyMock.preview)
        viewModel.state.audioSupport = .supported
        return viewModel
    }

    static var audioUnsupported: SettingsScreenViewModel {
        let viewModel = SettingsScreenViewModel(clientProxy: ClientProxyMock.preview)
        viewModel.state.audioSupport = .unsupported
        return viewModel
    }

    static var previews: some View {
        NavigationStack { SettingsScreen(context: SettingsScreenViewModel(clientProxy: ClientProxyMock.preview).context) }
            .previewDisplayName("Verified")
        NavigationStack { SettingsScreen(context: unverified.context) }
            .previewDisplayName("Unverified with verify row")
        NavigationStack { SettingsScreen(context: checkingVerification.context) }
            .previewDisplayName("Checking verification")
        NavigationStack { SettingsScreen(context: checkingAudioSupport.context) }
            .previewDisplayName("Checking audio support")
        NavigationStack { SettingsScreen(context: audioSupported.context) }
            .previewDisplayName("Opus supported")
        NavigationStack { SettingsScreen(context: audioUnsupported.context) }
            .previewDisplayName("Opus unsupported")
    }
}
