//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct LoginMethodScreen: View {
    let context: LoginMethodScreenViewModel.Context

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(context.viewState.options.serverName)
                    .font(.footnote)
                    .foregroundStyle(Color.compound.textSecondary)
                if context.viewState.options.supportsPassword {
                    Button(WatchStrings.signInWithPassword) { context.send(viewAction: .password) }
                        .buttonStyle(.fullWidthProminent)
                }
                if context.viewState.options.supportsQRCode {
                    Button(WatchStrings.signInWithQRCode) { context.send(viewAction: .qrCode) }
                        .buttonStyle(.fullWidthProminent)
                }
                if !context.viewState.options.supportsAnyMethod {
                    Text(WatchStrings.noSignInMethods).multilineTextAlignment(.center)
                }
            }
        }
        .navigationTitle(WatchStrings.signInMethodTitle)
    }
}

// MARK: - Previews

struct LoginMethodScreen_Previews: PreviewProvider {
    static var previews: some View {
        preview(password: true, qr: false, name: "Password only")
        preview(password: true, qr: true, name: "Both")
        preview(password: false, qr: false, name: "Unsupported")
    }

    static func preview(password: Bool, qr: Bool, name: String) -> some View {
        NavigationStack {
            LoginMethodScreen(context: LoginMethodScreenViewModel(options: LoginOptions(serverName: "matrix.org",
                                                                                        supportsPassword: password,
                                                                                        supportsQRCode: qr)).context)
        }
        .previewDisplayName(name)
    }
}
