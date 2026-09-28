//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import CoreLocation

enum LocationAuthorization: Equatable {
    case notDetermined
    case denied
    case authorized
}

enum LocationError: Error, Equatable {
    case denied
    case timedOut
    case failed
}

// sourcery: AutoMockable
protocol LocationProviderProtocol: AnyObject {
    var authorization: LocationAuthorization { get }
    var authorizationPublisher: AnyPublisher<LocationAuthorization, Never> { get }
    func requestAuthorization()
    /// One fix within `timeout`; `.denied` without asking if permission was refused.
    func currentLocation(timeout: Duration) async -> Result<GeoURI, LocationError>
    /// Continuous background updates for a live share (distance filter 10 m, nearest-ten-metres accuracy).
    var updatesPublisher: AnyPublisher<GeoURI, Never> { get }
    func startUpdates()
    func stopUpdates()
}

extension LocationAuthorization {
    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied, .restricted: self = .denied
        case .authorizedWhenInUse, .authorizedAlways: self = .authorized
        @unknown default: self = .denied
        }
    }
}

final class LocationProvider: NSObject, LocationProviderProtocol {
    private typealias FixContinuation = CheckedContinuation<Result<GeoURI, LocationError>, Never>

    private struct PendingFix {
        let continuation: FixContinuation
        let timeout: Duration
        /// Only started once authorized, so the first-use permission prompt doesn't eat into the timeout.
        var timeoutTask: Task<Void, Never>?
        /// Starts straight away so a prompt that is never answered (or never shown) can't leave the request stuck.
        var upperBoundTask: Task<Void, Never>?
    }

    /// How old `CLLocationManager.location` may be to answer a one-shot request during a live share.
    static let maximumCachedFixAge: TimeInterval = 60

    private let upperBound: Duration
    private let manager = CLLocationManager()
    private let authorizationSubject: CurrentValueSubject<LocationAuthorization, Never>
    private let updatesSubject = PassthroughSubject<GeoURI, Never>()
    /// One-shot requests awaiting a fix. Removed on first result so each resumes exactly once.
    private var pendingFixes: [UUID: PendingFix] = [:]
    private var isUpdating = false

    var authorization: LocationAuthorization { authorizationSubject.value }
    var authorizationPublisher: AnyPublisher<LocationAuthorization, Never> { authorizationSubject.eraseToAnyPublisher() }
    var updatesPublisher: AnyPublisher<GeoURI, Never> { updatesSubject.eraseToAnyPublisher() }

    /// - Parameter upperBound: The longest any request can take, including waiting for the permission prompt.
    init(upperBound: Duration = .seconds(120)) {
        self.upperBound = upperBound
        authorizationSubject = .init(LocationAuthorization(manager.authorizationStatus))
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        manager.delegate = self
    }

    func requestAuthorization() {
        guard authorization == .notDetermined else { return }
        MXLog.info("Requesting location authorization")
        manager.requestWhenInUseAuthorization()
    }

    func currentLocation(timeout: Duration) async -> Result<GeoURI, LocationError> {
        guard authorization != .denied else { return .failure(.denied) }
        // `requestLocation()` would cancel continuous updates, so a live share answers from its latest fix.
        if isUpdating, let fix = Self.recentFix(manager.location, now: .now) {
            return .success(fix)
        }

        let id = UUID()
        return await withCheckedContinuation { continuation in
            pendingFixes[id] = PendingFix(continuation: continuation, timeout: timeout, upperBoundTask: expire(id, after: upperBound))
            if authorization == .authorized {
                startTimeout(for: id)
                // During a live share the next update settles the request instead.
                if !isUpdating {
                    manager.requestLocation()
                }
            } else {
                requestAuthorization()
            }
        }
    }

    func startUpdates() {
        guard !isUpdating else { return }
        MXLog.info("Starting location updates")
        isUpdating = true
        // Requires the `location` UIBackgroundModes entry in Info.plist, otherwise Core Location traps.
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
    }

    func stopUpdates() {
        guard isUpdating else { return }
        MXLog.info("Stopping location updates")
        isUpdating = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        // Stopping also cancels any in-flight `requestLocation()`, so reissue it for requests still waiting.
        if !pendingFixes.isEmpty, authorization == .authorized {
            manager.requestLocation()
        }
    }

    /// `location` as a fix if it is valid (non-negative accuracy) and at most `maximumCachedFixAge` old.
    static func recentFix(_ location: CLLocation?, now: Date) -> GeoURI? {
        guard let location, location.horizontalAccuracy >= 0,
              now.timeIntervalSince(location.timestamp) <= maximumCachedFixAge else { return nil }
        return GeoURI(location)
    }

    private func startTimeout(for id: UUID) {
        guard let timeout = pendingFixes[id]?.timeout, pendingFixes[id]?.timeoutTask == nil else { return }
        pendingFixes[id]?.timeoutTask = expire(id, after: timeout)
    }

    private func expire(_ id: UUID, after duration: Duration) -> Task<Void, Never> {
        // Strongly captures self so a pending request can't outlive the provider unresolved.
        Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            MXLog.info("Location request timed out")
            self.finishFix(id, with: .failure(.timedOut))
        }
    }

    private func finishFix(_ id: UUID, with result: Result<GeoURI, LocationError>) {
        guard let pending = pendingFixes.removeValue(forKey: id) else { return }
        pending.timeoutTask?.cancel()
        pending.upperBoundTask?.cancel()
        pending.continuation.resume(returning: result)
    }

    private func finishAllFixes(with result: Result<GeoURI, LocationError>) {
        for id in pendingFixes.keys {
            finishFix(id, with: result)
        }
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorization = LocationAuthorization(manager.authorizationStatus)
        guard authorization != authorizationSubject.value else { return }
        MXLog.info("Location authorization changed: \(authorization)")
        authorizationSubject.send(authorization)

        switch authorization {
        case .denied:
            finishAllFixes(with: .failure(.denied))
        case .authorized where !pendingFixes.isEmpty:
            Array(pendingFixes.keys).forEach(startTimeout)
            if !isUpdating {
                manager.requestLocation()
            }
        case .authorized, .notDetermined:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // A negative accuracy marks an invalid fix.
        guard let location = locations.last(where: { $0.horizontalAccuracy >= 0 }) else { return }
        let geoURI = GeoURI(location)
        finishAllFixes(with: .success(geoURI))
        if isUpdating {
            updatesSubject.send(geoURI)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let code = (error as? CLError)?.code
        // Only the code: the error's description isn't ours to vouch for.
        MXLog.error("Location request failed: \(code.map { "CLError \($0.rawValue)" } ?? "\(type(of: error))")")
        // Transient during continuous updates: the next fix (or the timeout) settles pending requests.
        if isUpdating, code == .locationUnknown { return }
        finishAllFixes(with: .failure(code == .denied ? .denied : .failed))
    }
}

private extension GeoURI {
    init(_ location: CLLocation) {
        self.init(latitude: location.coordinate.latitude,
                  longitude: location.coordinate.longitude,
                  uncertainty: location.horizontalAccuracy)
    }
}
