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

    private let manager = CLLocationManager()
    private let authorizationSubject: CurrentValueSubject<LocationAuthorization, Never>
    private let updatesSubject = PassthroughSubject<GeoURI, Never>()
    /// One-shot requests awaiting a fix, each with its timeout. Removed on first result so each resumes exactly once.
    private var pendingFixes: [UUID: (continuation: FixContinuation, timeoutTask: Task<Void, Never>)] = [:]
    private var isUpdating = false

    var authorization: LocationAuthorization { authorizationSubject.value }
    var authorizationPublisher: AnyPublisher<LocationAuthorization, Never> { authorizationSubject.eraseToAnyPublisher() }
    var updatesPublisher: AnyPublisher<GeoURI, Never> { updatesSubject.eraseToAnyPublisher() }

    override init() {
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
        requestAuthorization()

        let id = UUID()
        return await withCheckedContinuation { continuation in
            // Strongly captures self so a pending request can't outlive the provider unresolved.
            let timeoutTask = Task {
                try? await Task.sleep(for: timeout)
                guard !Task.isCancelled else { return }
                MXLog.info("Location request timed out")
                self.finishFix(id, with: .failure(.timedOut))
            }
            pendingFixes[id] = (continuation, timeoutTask)
            manager.requestLocation()
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
    }

    private func finishFix(_ id: UUID, with result: Result<GeoURI, LocationError>) {
        guard let pending = pendingFixes.removeValue(forKey: id) else { return }
        pending.timeoutTask.cancel()
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
        if authorization == .denied {
            finishAllFixes(with: .failure(.denied))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // A negative accuracy marks an invalid fix.
        guard let location = locations.last(where: { $0.horizontalAccuracy >= 0 }) else { return }
        let geoURI = GeoURI(latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            uncertainty: location.horizontalAccuracy)
        finishAllFixes(with: .success(geoURI))
        if isUpdating {
            updatesSubject.send(geoURI)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        MXLog.error("Location request failed: \(error)")
        let isDenied = (error as? CLError)?.code == .denied
        finishAllFixes(with: .failure(isDenied ? .denied : .failed))
    }
}
