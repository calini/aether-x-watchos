//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct AttachmentsScreen: View {
    let context: AttachmentsScreenViewModel.Context

    var body: some View {
        List {
            Button(WatchStrings.locationRow) { context.send(viewAction: .location) }
            Button(WatchStrings.voiceMessageRow) { context.send(viewAction: .voiceMessage) }
        }
        .navigationTitle(WatchStrings.attachmentsTitle)
    }
}

// MARK: - Previews

struct AttachmentsScreen_Previews: PreviewProvider {
    static let viewModel = AttachmentsScreenViewModel()

    static var previews: some View {
        NavigationStack { AttachmentsScreen(context: viewModel.context) }
    }
}
