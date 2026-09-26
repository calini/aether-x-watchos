//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementXWatch
import Testing

@Suite
struct SettingsScreenViewModelTests {
    @Test
    func showsIdentityAndVerification() async throws {
        let setup = Setup()
        setup.verification.send(.unverified)
        let viewModel = SettingsScreenViewModel(clientProxy: setup.clientProxy)

        try await waitUntil { viewModel.context.viewState.displayName == "Me" }
        #expect(viewModel.context.viewState.userID == "@me:example.org")
        #expect(viewModel.context.viewState.verification == .unverified)
    }

    @Test
    func signOutNeedsConfirmation() {
        let viewModel = SettingsScreenViewModel(clientProxy: Setup().clientProxy)
        var signedOut = false
        let cancellable = viewModel.actionsPublisher.sink { if case .signOut = $0 { signedOut = true } }

        viewModel.context.send(viewAction: .signOut)
        #expect(viewModel.context.viewState.bindings.isConfirmingSignOut)
        #expect(!signedOut)

        viewModel.context.send(viewAction: .confirmSignOut)
        #expect(signedOut)
        cancellable.cancel()
    }

    @Test
    func unverifiedSessionsCanVerify() async throws {
        let setup = Setup()
        setup.verification.send(.unverified)
        let viewModel = SettingsScreenViewModel(clientProxy: setup.clientProxy)
        var requested = false
        let cancellable = viewModel.actionsPublisher.sink { if case .verifySession = $0 { requested = true } }

        try await waitUntil { viewModel.context.viewState.canVerify }
        viewModel.context.send(viewAction: .verifySession)

        #expect(requested)
        setup.verification.send(.verified)
        try await waitUntil { !viewModel.context.viewState.canVerify }
        cancellable.cancel()
    }
}
