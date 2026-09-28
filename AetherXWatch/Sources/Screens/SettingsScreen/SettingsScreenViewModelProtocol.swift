//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine

protocol SettingsScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<SettingsScreenViewModelAction, Never> { get }
    var context: SettingsScreenViewModel.Context { get }
}
