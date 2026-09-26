//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Observation
import SwiftUI

enum AttachmentsScreenCoordinatorAction {
    case dismiss
}

/// The (+) sheet: the attachment types, each pushing its own screen.
final class AttachmentsScreenCoordinator: CoordinatorProtocol {
    @Observable final class Navigation {
        var locationSharing: LocationSharingScreenCoordinator?
    }

    private let viewModel = AttachmentsScreenViewModel()
    private let makeLocationSharing: () -> LocationSharingScreenCoordinator
    private let navigation = Navigation()
    private let actionsSubject = PassthroughSubject<AttachmentsScreenCoordinatorAction, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var locationSharingCancellable: AnyCancellable?

    var actionsPublisher: AnyPublisher<AttachmentsScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(makeLocationSharing: @escaping () -> LocationSharingScreenCoordinator) {
        self.makeLocationSharing = makeLocationSharing
    }

    func start() {
        viewModel.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .location: self?.showLocationSharing()
                }
            }
            .store(in: &cancellables)
    }

    func toPresentable() -> AnyView {
        AnyView(AttachmentsFlowView(navigation: navigation, root: AttachmentsScreen(context: viewModel.context)))
    }

    private func showLocationSharing() {
        let coordinator = makeLocationSharing()
        locationSharingCancellable = coordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .done: self?.actionsSubject.send(.dismiss)
                }
            }
        coordinator.start()
        navigation.locationSharing = coordinator
    }
}

private struct AttachmentsFlowView: View {
    @Bindable var navigation: AttachmentsScreenCoordinator.Navigation
    let root: AttachmentsScreen

    private var isShowingLocationSharing: Binding<Bool> {
        Binding(get: { navigation.locationSharing != nil },
                set: { if !$0 { navigation.locationSharing = nil } })
    }

    var body: some View {
        NavigationStack {
            root.navigationDestination(isPresented: isShowingLocationSharing) {
                navigation.locationSharing?.toPresentable()
            }
        }
    }
}
