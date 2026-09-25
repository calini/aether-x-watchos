//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import Observation

/// A common ViewModel implementation for handling of `State` and `ViewAction`s using Swift Observation.
class StateStoreViewModelV2<State: BindableState, ViewAction> {
    /// For storing subscription references.
    var cancellables = Set<AnyCancellable>()

    /// Constrained interface for passing to Views.
    var context: Context

    var state: State {
        get { context.viewState }
        set { context.viewState = newValue }
    }

    init(initialViewState: State) {
        context = Context(initialViewState: initialViewState)
        context.viewModel = self
    }

    /// Override to handle incoming `ViewAction`s from the view.
    func process(viewAction: ViewAction) { }

    // MARK: - Context

    /// The view's interface to the view model: read state, send actions, bind to `bindings`.
    @dynamicMemberLookup
    @Observable final class Context {
        fileprivate weak var viewModel: StateStoreViewModelV2?

        fileprivate(set) var viewState: State

        subscript<T>(dynamicMember keyPath: WritableKeyPath<State.BindStateType, T>) -> T {
            get { viewState.bindings[keyPath: keyPath] }
            set { viewState.bindings[keyPath: keyPath] = newValue }
        }

        func send(viewAction: ViewAction) {
            viewModel?.process(viewAction: viewAction)
        }

        fileprivate init(initialViewState: State) {
            viewState = initialViewState
        }
    }
}
