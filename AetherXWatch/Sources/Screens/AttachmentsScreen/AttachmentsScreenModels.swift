//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

struct AttachmentsScreenViewState: BindableState { }

enum AttachmentsScreenViewAction {
    case location
    case voiceMessage
}

enum AttachmentsScreenViewModelAction {
    case location
    case voiceMessage
}
