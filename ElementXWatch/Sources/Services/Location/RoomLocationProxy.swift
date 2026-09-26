//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import MatrixRustSDK

enum LocationProxyError: Error, Equatable {
    case sdkError(String)
}

// sourcery: AutoMockable
protocol RoomLocationProxyProtocol: AnyObject, Sendable {
    var roomID: String { get }
    /// Other people's (and our own) active live shares in this room.
    var liveLocationsPublisher: AnyPublisher<[LiveLocationSummary], Never> { get }

    /// Succeeds with the `beacon_info` event ID.
    func startLiveLocationShare(duration: Duration) async -> Result<String, LocationProxyError>
    func sendLiveLocation(_ geoURI: GeoURI) async -> Result<Void, LocationProxyError>
    func stopLiveLocationShare() async -> Result<Void, LocationProxyError>
}

final class RoomLocationProxy: RoomLocationProxyProtocol {
    private let room: Room
    private let liveLocationsSubject = CurrentValueSubject<[LiveLocationSummary], Never>([])
    /// Keeps the SDK's beacon event handlers registered: releasing it while `liveLocationsHandle` runs stops the updates.
    // periphery:ignore - retaining purpose
    private var liveLocationsObserver: LiveLocationsObserver?
    private var liveLocationsHandle: TaskHandle?

    var roomID: String { room.id() }
    var liveLocationsPublisher: AnyPublisher<[LiveLocationSummary], Never> { liveLocationsSubject.eraseToAnyPublisher() }

    init(room: Room) {
        self.room = room
    }

    deinit {
        // Cancelled before the observer it depends on is released.
        liveLocationsHandle?.cancel()
    }

    func start() async {
        guard liveLocationsHandle == nil else { return }
        let observer = await room.liveLocationsObserver()
        liveLocationsObserver = observer
        liveLocationsHandle = observer.subscribe(listener: SDKListener<[LiveLocationShareUpdate]>.onMainActor { [weak self] updates in
            guard let self else { return }
            let summaries = LiveLocationSummaries.apply(updates, to: liveLocationsSubject.value)
            MXLog.info("Live location shares in the room: \(summaries.count)")
            liveLocationsSubject.send(summaries)
        })
    }

    func startLiveLocationShare(duration: Duration) async -> Result<String, LocationProxyError> {
        do {
            let eventID = try await room.startLiveLocationShare(durationMillis: UInt64(duration / .milliseconds(1)))
            MXLog.info("Started a live location share: \(eventID)")
            return .success(eventID)
        } catch {
            MXLog.error("Starting a live location share failed: \(error)")
            return .failure(.sdkError(error.localizedDescription))
        }
    }

    func sendLiveLocation(_ geoURI: GeoURI) async -> Result<Void, LocationProxyError> {
        do {
            try await room.sendLiveLocation(geoUri: geoURI.string)
            return .success(())
        } catch {
            // Only the type: the SDK's message could echo the geo URI.
            MXLog.error("Sending a live location update failed: \(type(of: error))")
            return .failure(.sdkError(error.localizedDescription))
        }
    }

    func stopLiveLocationShare() async -> Result<Void, LocationProxyError> {
        do {
            try await room.stopLiveLocationShare()
            MXLog.info("Stopped the live location share")
            return .success(())
        } catch {
            MXLog.error("Stopping a live location share failed: \(error)")
            return .failure(.sdkError(error.localizedDescription))
        }
    }
}
