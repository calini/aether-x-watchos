//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine

protocol SessionVerificationScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<SessionVerificationScreenViewModelAction, Never> { get }
    var context: SessionVerificationScreenViewModel.Context { get }
}
