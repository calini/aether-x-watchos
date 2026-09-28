//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

struct LocationSharingScreen: View {
    @Bindable var context: LocationSharingScreenViewModel.Context

    private var viewState: LocationSharingScreenViewState {
        context.viewState
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                preview
                if viewState.isBusy {
                    ProgressView()
                }
                buttons
            }
        }
        .navigationTitle(WatchStrings.locationTitle)
        .onAppear { context.send(viewAction: .appear) }
        .alert(WatchStrings.replaceLiveShareTitle(roomName: viewState.otherShareRoomName ?? WatchStrings.anotherChat),
               isPresented: isConfirmingReplace) {
            Button(WatchStrings.shareHere) { context.send(viewAction: .confirmReplace) }
            Button(WatchStrings.cancel, role: .cancel) { context.send(viewAction: .cancelReplace) }
        }
        .alert(viewState.bindings.errorMessage ?? "", isPresented: isShowingError) {
            Button(WatchStrings.ok) { }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if viewState.authorization == .denied {
            Text(WatchStrings.locationAccessOff)
                .font(.footnote)
                .foregroundStyle(Color.compound.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if viewState.locateFailed {
            VStack(spacing: 4) {
                Text(WatchStrings.locationFailed)
                    .font(.footnote)
                    .foregroundStyle(Color.compound.textSecondary)
                Button(WatchStrings.tryAgain) { context.send(viewAction: .tryAgain) }
                    .buttonStyle(.fullWidth)
            }
        } else if let geoURI = viewState.geoURI {
            map(of: geoURI)
        } else {
            mapPlaceholder {
                VStack(spacing: 4) {
                    ProgressView()
                    Text(WatchStrings.findingLocation)
                        .font(.caption2)
                        .foregroundStyle(Color.compound.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func map(of geoURI: GeoURI) -> some View {
        if let snapshot = viewState.snapshot {
            Image(uiImage: snapshot)
                .resizable()
                .aspectRatio(LocationSharingScreenViewModel.snapshotSize, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel(WatchStrings.location)
        } else if viewState.snapshotFailed {
            mapPlaceholder {
                VStack(spacing: 2) {
                    Text(WatchStrings.locationPlaceholderIcon).font(.title3)
                    Text(String(format: "%.3f, %.3f", geoURI.latitude, geoURI.longitude))
                        .font(.caption2)
                        .foregroundStyle(Color.compound.textSecondary)
                }
            }
        } else {
            mapPlaceholder { ProgressView() }
        }
    }

    private func mapPlaceholder(@ViewBuilder content: () -> some View) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.compound.bgSubtleSecondary)
            .aspectRatio(LocationSharingScreenViewModel.snapshotSize, contentMode: .fit)
            .overlay(content: content)
    }

    private var buttons: some View {
        VStack(spacing: 6) {
            Button(WatchStrings.sendCurrentLocation) { context.send(viewAction: .sendCurrent) }
                .buttonStyle(.fullWidthProminent)
                .disabled(!viewState.canSendCurrent)
            ForEach(LiveShareDuration.allCases, id: \.self) { duration in
                Button(duration.title) { context.send(viewAction: .shareLive(duration)) }
                    .buttonStyle(.fullWidth)
                    .disabled(!viewState.canShareLive)
            }
        }
    }

    private var isConfirmingReplace: Binding<Bool> {
        Binding(get: { context.viewState.bindings.confirmReplace != nil },
                set: { if !$0 { context.confirmReplace = nil } })
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { context.viewState.bindings.errorMessage != nil },
                set: { if !$0 { context.errorMessage = nil } })
    }
}

// MARK: - Previews

struct LocationSharingScreen_Previews: PreviewProvider {
    static let geoURI = GeoURI(latitude: 51.5072, longitude: -0.1276, uncertainty: 5)

    // Kept alive by the previews: a context only weakly references its view model.
    static let locating = makeViewModel(location: nil)
    static let located = makeViewModel(location: .success(geoURI))
    static let failed = makeViewModel(location: .failure(.timedOut))
    static let denied = makeViewModel(authorization: .denied, location: .failure(.denied))
    static let confirmingReplace = {
        let viewModel = makeViewModel(sharingElsewhere: true, location: .success(geoURI))
        viewModel.context.send(viewAction: .shareLive(.fifteenMinutes))
        return viewModel
    }()

    static var previews: some View {
        screen(locating)
            .previewDisplayName("Locating")
        screen(located)
            .previewDisplayName("Located")
        screen(failed)
            .previewDisplayName("Failed")
        screen(denied)
            .previewDisplayName("Denied")
        screen(confirmingReplace)
            .previewDisplayName("Replace confirmation")
    }

    static func screen(_ viewModel: LocationSharingScreenViewModel) -> some View {
        NavigationStack { LocationSharingScreen(context: viewModel.context) }
    }

    static func makeViewModel(authorization: LocationAuthorization = .authorized,
                              sharingElsewhere: Bool = false,
                              location: Result<GeoURI, LocationError>?) -> LocationSharingScreenViewModel {
        let locationProvider = LocationProviderMock()
        locationProvider.authorization = authorization
        locationProvider.authorizationPublisher = Just(authorization).eraseToAnyPublisher()
        if let location {
            locationProvider.currentLocationTimeoutReturnValue = location
        } else {
            // Never resolves, so the preview stays on "Finding your location…".
            locationProvider.currentLocationTimeoutClosure = { _ in
                try? await Task.sleep(for: .seconds(999))
                return .failure(.timedOut)
            }
        }

        let liveLocationService = LiveLocationServiceMock()
        liveLocationService.state = sharingElsewhere ? .sharing(roomID: "!other:x", endsAt: .now.addingTimeInterval(600), isPaused: false) : .idle
        liveLocationService.statePublisher = Just(liveLocationService.state).eraseToAnyPublisher()
        liveLocationService.startRoomIDDurationReturnValue = .success(())

        return LocationSharingScreenViewModel(roomID: "!room:x",
                                              roomName: { _ in "Climbing crew" },
                                              locationProvider: locationProvider,
                                              liveLocationService: liveLocationService,
                                              sendLocation: { _ in .success(()) },
                                              snapshotLoader: MapSnapshotLoader())
    }
}
