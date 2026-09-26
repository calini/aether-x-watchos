//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementXWatch
import SwiftUI
import Testing

struct LocationSharingScreenViewModelTests {
    @Test
    func appearRequestsPermissionAndLocates() async throws {
        let harness = Harness(authorization: .notDetermined)
        let gate = AsyncGate()
        harness.locationProvider.currentLocationTimeoutClosure = { _ in
            await gate.wait()
            return .success(.here)
        }

        harness.send(.appear)

        #expect(harness.locationProvider.requestAuthorizationCallsCount == 1)
        try await waitUntil { harness.locationProvider.currentLocationTimeoutCalled }
        #expect(harness.locationProvider.currentLocationTimeoutReceivedTimeout == .seconds(30))
        #expect(harness.viewState.isLocating)
        #expect(!harness.viewState.canSendCurrent)

        harness.authorization.send(.authorized)
        await gate.open()

        try await waitUntil { harness.viewState.geoURI == .here }
        #expect(!harness.viewState.isLocating)
        #expect(!harness.viewState.locateFailed)
        #expect(harness.viewState.authorization == .authorized)
        #expect(harness.viewState.canSendCurrent)
        #expect(harness.viewState.canShareLive)
    }

    @Test
    func appearingTwiceLocatesOnce() async throws {
        let harness = Harness()

        harness.send(.appear)
        harness.send(.appear)

        try await waitUntil { harness.viewState.geoURI == .here }
        #expect(harness.locationProvider.currentLocationTimeoutCallsCount == 1)
    }

    @Test
    func deniedPermissionDisablesSharing() async throws {
        let harness = Harness(authorization: .denied)
        harness.locationProvider.currentLocationTimeoutReturnValue = .failure(.denied)

        harness.send(.appear)

        #expect(harness.viewState.authorization == .denied)
        #expect(harness.locationProvider.requestAuthorizationCallsCount == 0)
        #expect(!harness.viewState.isLocating)
        #expect(!harness.viewState.canSendCurrent)
        #expect(!harness.viewState.canShareLive)
    }

    @Test
    func decliningThePromptDisablesSharing() async throws {
        let harness = Harness(authorization: .notDetermined)
        harness.locationProvider.currentLocationTimeoutReturnValue = .failure(.denied)

        harness.send(.appear)

        try await waitUntil { harness.viewState.authorization == .denied }
        #expect(!harness.viewState.isLocating)
        #expect(!harness.viewState.locateFailed)
        #expect(!harness.viewState.canSendCurrent)
        #expect(!harness.viewState.canShareLive)
    }

    @Test
    func timeoutShowsTryAgain() async throws {
        let harness = Harness()
        harness.locationProvider.currentLocationTimeoutReturnValue = .failure(.timedOut)

        harness.send(.appear)

        try await waitUntil { harness.viewState.locateFailed }
        #expect(!harness.viewState.isLocating)
        #expect(harness.viewState.geoURI == nil)
        #expect(!harness.viewState.canSendCurrent)
        // A live share doesn't need the first fix: the service waits for one.
        #expect(harness.viewState.canShareLive)

        harness.locationProvider.currentLocationTimeoutReturnValue = .success(.here)
        harness.send(.tryAgain)

        try await waitUntil { harness.viewState.geoURI == .here }
        #expect(!harness.viewState.locateFailed)
        #expect(harness.locationProvider.currentLocationTimeoutCallsCount == 2)
    }

    @Test
    func locatingLoadsTheSnapshot() async throws {
        let harness = Harness()
        let image = UIImage(systemName: "mappin")
        harness.snapshotLoader.snapshotOfSizeReturnValue = image

        harness.send(.appear)

        try await waitUntil { harness.viewState.snapshot != nil }
        #expect(harness.snapshotLoader.snapshotOfSizeReceivedArguments?.geoURI == .here)
    }

    @Test
    func sendCurrentSendsAndFinishes() async throws {
        let harness = try await Harness.located()
        let gate = AsyncGate()
        var sent: [GeoURI] = []
        harness.sendLocation = { geoURI in
            sent.append(geoURI)
            await gate.wait()
            return .success(())
        }

        harness.send(.sendCurrent)

        #expect(harness.viewState.isBusy)
        #expect(!harness.viewState.canSendCurrent)
        #expect(!harness.viewState.canShareLive)
        await gate.open()
        try await waitUntil { harness.actions == [.done] }
        #expect(sent == [.here])
    }

    @Test
    func sendFailureShowsError() async throws {
        let harness = try await Harness.located()
        harness.sendLocation = { _ in .failure(.sdkError("boom")) }

        harness.send(.sendCurrent)

        try await waitUntil { harness.viewState.bindings.errorMessage == WatchStrings.sendLocationFailed }
        #expect(!harness.viewState.isBusy)
        #expect(harness.actions.isEmpty)
    }

    @Test
    func shareLiveStartsAndFinishes() async throws {
        let harness = try await Harness.located()
        let gate = AsyncGate()
        harness.liveLocationService.startRoomIDDurationClosure = { _, _ in
            await gate.wait()
            return .success(())
        }

        harness.send(.shareLive(.oneHour))

        try await waitUntil { harness.liveLocationService.startRoomIDDurationCalled }
        // Starting can wait for a relaunch's restore, so the sheet stays busy meanwhile.
        #expect(harness.viewState.isBusy)
        #expect(!harness.viewState.canShareLive)
        #expect(!harness.viewState.canSendCurrent)
        await gate.open()
        try await waitUntil { harness.actions == [.done] }
        #expect(harness.liveLocationService.startRoomIDDurationReceivedArguments?.roomID == Harness.roomID)
        #expect(harness.liveLocationService.startRoomIDDurationReceivedArguments?.duration == .seconds(3600))
    }

    @Test
    func shareLiveFailureShowsError() async throws {
        let harness = try await Harness.located()
        harness.liveLocationService.startRoomIDDurationReturnValue = .failure(.startFailed)

        harness.send(.shareLive(.fifteenMinutes))

        try await waitUntil { harness.viewState.bindings.errorMessage == WatchStrings.startLiveFailed }
        #expect(!harness.viewState.isBusy)
        #expect(harness.actions.isEmpty)
    }

    @Test
    func shareLiveInThisRoomRestartsWithoutAsking() async throws {
        let harness = try await Harness.located()
        harness.liveLocationService.state = .sharing(roomID: Harness.roomID, endsAt: .now, isPaused: false)

        harness.send(.shareLive(.fifteenMinutes))

        try await waitUntil { harness.actions == [.done] }
        #expect(harness.viewState.bindings.confirmReplace == nil)
    }

    @Test
    func shareLiveWhileSharingElsewhereAsksFirst() async throws {
        let harness = try await Harness.located()
        harness.liveLocationService.state = .sharing(roomID: "!other:x", endsAt: .now, isPaused: false)

        harness.send(.shareLive(.fifteenMinutes))

        #expect(harness.viewState.bindings.confirmReplace == .fifteenMinutes)
        #expect(harness.viewState.otherShareRoomName == "Climbing crew")
        #expect(!harness.liveLocationService.startRoomIDDurationCalled)
    }

    @Test
    func anUnknownOtherRoomIsAnotherChat() async throws {
        let harness = try await Harness.located()
        harness.liveLocationService.state = .sharing(roomID: "!unknown:x", endsAt: .now, isPaused: false)

        harness.send(.shareLive(.oneHour))

        #expect(harness.viewState.otherShareRoomName == WatchStrings.anotherChat)
    }

    @Test
    func confirmReplaceStartsHere() async throws {
        let harness = try await Harness.located()
        harness.liveLocationService.state = .sharing(roomID: "!other:x", endsAt: .now, isPaused: false)
        harness.send(.shareLive(.oneHour))
        // The alert clears its binding as it closes, possibly before the button's action runs.
        harness.viewModel.context.confirmReplace = nil

        harness.send(.confirmReplace)

        try await waitUntil { harness.actions == [.done] }
        #expect(harness.liveLocationService.startRoomIDDurationReceivedArguments?.roomID == Harness.roomID)
        #expect(harness.liveLocationService.startRoomIDDurationReceivedArguments?.duration == .seconds(3600))
    }

    @Test
    func cancelReplaceDoesNothing() async throws {
        let harness = try await Harness.located()
        harness.liveLocationService.state = .sharing(roomID: "!other:x", endsAt: .now, isPaused: false)
        harness.send(.shareLive(.oneHour))

        harness.send(.cancelReplace)
        harness.send(.confirmReplace)

        #expect(harness.viewState.bindings.confirmReplace == nil)
        #expect(!harness.liveLocationService.startRoomIDDurationCalled)
        #expect(harness.actions.isEmpty)
    }
}

private final class Harness {
    static let roomID = "!room:x"

    let locationProvider = LocationProviderMock()
    let authorization: CurrentValueSubject<LocationAuthorization, Never>
    let liveLocationService = LiveLocationServiceMock()
    let snapshotLoader = MapSnapshotLoaderMock()
    var sendLocation: (GeoURI) async -> Result<Void, TimelineProxyError> = { _ in .success(()) }
    private(set) var actions: [LocationSharingScreenViewModelAction] = []
    private(set) var viewModel: LocationSharingScreenViewModel!
    private var cancellable: AnyCancellable?

    var viewState: LocationSharingScreenViewState {
        viewModel.context.viewState
    }

    init(authorization: LocationAuthorization = .authorized) {
        self.authorization = .init(authorization)
        locationProvider.authorization = authorization
        locationProvider.authorizationPublisher = self.authorization.eraseToAnyPublisher()
        locationProvider.currentLocationTimeoutReturnValue = .success(.here)
        liveLocationService.state = .idle
        liveLocationService.startRoomIDDurationReturnValue = .success(())

        viewModel = LocationSharingScreenViewModel(roomID: Self.roomID,
                                                   roomName: { $0 == "!other:x" ? "Climbing crew" : nil },
                                                   locationProvider: locationProvider,
                                                   liveLocationService: liveLocationService,
                                                   sendLocation: { [unowned self] in await sendLocation($0) },
                                                   snapshotLoader: snapshotLoader)
        cancellable = viewModel.actionsPublisher.sink { [unowned self] in actions.append($0) }
    }

    /// A harness whose sheet has appeared and found `.here`.
    static func located() async throws -> Harness {
        let harness = Harness()
        harness.send(.appear)
        try await waitUntil { harness.viewState.geoURI == .here }
        return harness
    }

    func send(_ action: LocationSharingScreenViewAction) {
        viewModel.context.send(viewAction: action)
    }
}

private extension GeoURI {
    static let here = GeoURI(latitude: 51.5072, longitude: -0.1276, uncertainty: 5)
}
