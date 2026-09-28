//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct QRLoginScreen: View {
    @Bindable var context: QRLoginScreenViewModel.Context

    var body: some View {
        content
            .navigationTitle(WatchStrings.appName)
    }

    @ViewBuilder
    private var content: some View {
        switch context.viewState.step {
        case .intro:
            ScrollView {
                VStack(spacing: 8) {
                    Text(WatchStrings.signInTitle).font(.headline)
                    Text(WatchStrings.signInInstructions)
                        .font(.footnote)
                        .foregroundStyle(Color.compound.textSecondary)
                    Button(WatchStrings.signInStart) { context.send(viewAction: .start) }
                        .tint(Color.compound.bgAccentRest)
                }
            }
        case .preparing, .sendingCheckCode:
            ProgressView(WatchStrings.preparing)
        case .showingQRCode(let data):
            QRCodeView(data: data)
                .ignoresSafeArea(edges: .bottom)
                .toolbar { cancelButton }
        case .enteringCheckCode:
            checkCodeEntry
        case .waitingForApproval(let userCode):
            VStack(spacing: 6) {
                ProgressView()
                Text(WatchStrings.approveOnPhone).font(.headline)
                Text("\(WatchStrings.approvalCode): \(userCode)").font(.footnote.monospaced())
            }
            .toolbar { cancelButton }
        case .syncingSecrets:
            ProgressView(WatchStrings.syncingKeys)
        case .failed(let error):
            ScrollView {
                VStack(spacing: 8) {
                    Text(error.message).multilineTextAlignment(.center)
                    Button(WatchStrings.tryAgain) { context.send(viewAction: .retry) }
                }
            }
        }
    }

    private var checkCodeEntry: some View {
        VStack(spacing: 4) {
            Text(WatchStrings.enterCheckCode).font(.footnote).multilineTextAlignment(.center)
            Picker(WatchStrings.approvalCode, selection: $context.checkCode) {
                ForEach(0..<100, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .labelsHidden()
            .frame(height: 60)
            Button(WatchStrings.confirm) { context.send(viewAction: .submitCheckCode) }
        }
        .toolbar { cancelButton }
    }

    private var cancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(WatchStrings.cancel) { context.send(viewAction: .cancel) }
        }
    }
}

// MARK: - Previews

struct QRLoginScreen_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(steps, id: \.0) { name, step in
            NavigationStack { QRLoginScreen(context: makeViewModel(step: step).context) }
                .previewDisplayName(name)
        }
    }

    static let steps: [(String, QRLoginScreenStep)] = [
        ("Intro", .intro),
        ("Preparing", .preparing),
        ("QR code", .showingQRCode(Data((0..<120).map { UInt8($0) }))),
        ("Check code", .enteringCheckCode),
        ("Approve", .waitingForApproval(userCode: "7XK2")),
        ("Syncing", .syncingSecrets),
        ("Failed", .failed(.expired))
    ]

    static func makeViewModel(step: QRLoginScreenStep) -> QRLoginScreenViewModel {
        let viewModel = QRLoginScreenViewModel(qrLoginService: QRLoginServiceMock())
        viewModel.state.step = step
        return viewModel
    }
}
