//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

@main
struct AetherXWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appCoordinator: AppCoordinator

    init() {
        Tracing.setUp()

        let keychainStore = KeychainStore(service: WatchAppSettings.keychainService)
        let sessionStore = SessionStore(keychainStore: keychainStore)
        let clientFactory = ClientFactory(transport: URLSessionTransport(), sessionDelegate: SessionDelegate(keychainStore: keychainStore))
        let authenticationService = AuthenticationService(clientFactory: clientFactory, sessionStore: sessionStore)
        _appCoordinator = State(initialValue: AppCoordinator(sessionStore: sessionStore,
                                                              restorer: UserSessionRestorer(sessionStore: sessionStore, clientFactory: clientFactory),
                                                              authenticationService: authenticationService,
                                                              qrLoginService: authenticationService))
    }

    var body: some Scene {
        WindowGroup {
            appCoordinator.toPresentable()
                .task { await appCoordinator.start() }
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            appCoordinator.handleScenePhase(newPhase)
        }
    }
}
