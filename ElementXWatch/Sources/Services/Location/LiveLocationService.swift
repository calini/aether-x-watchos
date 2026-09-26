//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import CoreLocation

enum LiveLocationState: Equatable {
    case idle
    case sharing(roomID: String, endsAt: Date, isPaused: Bool)
}

enum LiveLocationServiceError: Error, Equatable {
    case startFailed
    case noLocationAccess
}

// sourcery: AutoMockable
protocol LiveLocationServiceProtocol: AnyObject {
    var state: LiveLocationState { get }
    var statePublisher: AnyPublisher<LiveLocationState, Never> { get }
    /// Resumes a share this device started before a relaunch, if it is still live, otherwise ends it.
    /// Idempotent: safe to call again, e.g. once the room list has loaded if the room wasn't available yet.
    func restore() async
    /// Stops any share in another room first (callers confirm with the user before calling).
    func start(roomID: String, duration: Duration) async -> Result<Void, LiveLocationServiceError>
    func stop() async
}

/// The share this device started, kept so a relaunch can resume it.
struct LiveLocationShareRecord: Codable, Equatable {
    let roomID: String
    let eventID: String
    let endsAt: Date
}

protocol LiveLocationShareStoreProtocol: AnyObject {
    func load() -> LiveLocationShareRecord?
    func save(_ record: LiveLocationShareRecord)
    func clear()
}

final class UserDefaultsLiveLocationShareStore: LiveLocationShareStoreProtocol {
    private let key: String
    private let defaults: UserDefaults

    init(userID: String, defaults: UserDefaults = .standard) {
        key = "liveLocationShare.\(userID)"
        self.defaults = defaults
    }

    func load() -> LiveLocationShareRecord? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(LiveLocationShareRecord.self, from: $0) }
    }

    func save(_ record: LiveLocationShareRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

/// Owns the session's single live location share: starts it, sends updates on a rhythm, and ends it.
final class LiveLocationService: LiveLocationServiceProtocol {
    static let minimumDistance: CLLocationDistance = 20
    static let minimumInterval: Duration = .seconds(30)
    static let keepAliveInterval: Duration = .seconds(180)
    static let maxFailuresBeforePause = 3
    /// How long a relaunch waits for the room's live shares to load before giving up on resuming.
    static let restoreTimeout: Duration = .seconds(10)

    /// The share in progress. Compared by identity so async work for an ended share is dropped.
    private final class ActiveShare {
        let roomID: String
        /// Held for the share's lifetime: every `roomLocationProxy(for:)` call builds a new room observer.
        let roomProxy: RoomLocationProxyProtocol
        let eventID: String
        let endsAt: Date
        var lastSentFix: GeoURI?
        var lastAttemptDate: Date?
        var lastAttemptFailed = false
        var consecutiveFailures = 0
        var isSending = false
        var sentCount = 0

        init(roomID: String, roomProxy: RoomLocationProxyProtocol, eventID: String, endsAt: Date) {
            self.roomID = roomID
            self.roomProxy = roomProxy
            self.eventID = eventID
            self.endsAt = endsAt
        }
    }

    private let ownUserID: String
    private let locationProvider: LocationProviderProtocol
    private let roomProvider: (String) async -> RoomLocationProxyProtocol?
    private let store: LiveLocationShareStoreProtocol
    /// Makes a sleep on the injected clock whose deadline is fixed when it's made.
    private let makeSleep: (Duration) -> @Sendable () async throws -> Void
    private let now: () -> Date
    private let stateSubject = CurrentValueSubject<LiveLocationState, Never>(.idle)
    private var activeShare: ActiveShare?
    private var isStarting = false
    /// The restore in progress, awaited by `start` and `stop` so a resumed share can't outlive them.
    private var restoreTask: Task<Void, Never>?
    /// Non-nil while Core Location updates run for us.
    private var updatesCancellable: AnyCancellable?
    private var latestFix: GeoURI?
    private var ownBeaconInfoCancellable: AnyCancellable?
    private var timerTask: Task<Void, Never>?

    var state: LiveLocationState { stateSubject.value }
    var statePublisher: AnyPublisher<LiveLocationState, Never> { stateSubject.eraseToAnyPublisher() }

    init(ownUserID: String,
         locationProvider: LocationProviderProtocol,
         roomProvider: @escaping (String) async -> RoomLocationProxyProtocol?,
         ownBeaconInfoPublisher: AnyPublisher<OwnBeaconInfo, Never>,
         store: LiveLocationShareStoreProtocol,
         clock: some Clock<Duration> = ContinuousClock(),
         now: @escaping () -> Date = Date.init) {
        self.ownUserID = ownUserID
        self.locationProvider = locationProvider
        self.roomProvider = roomProvider
        self.store = store
        makeSleep = { duration in Self.sleep(on: clock, for: duration) }
        self.now = now
        ownBeaconInfoCancellable = ownBeaconInfoPublisher.sink { [weak self] info in
            self?.handleOwnBeaconInfo(info)
        }
    }

    isolated deinit {
        timerTask?.cancel()
        if updatesCancellable != nil {
            locationProvider.stopUpdates()
        }
    }

    func restore() async {
        if let restoreTask {
            await restoreTask.value
            return
        }
        let task = Task { await performRestore() }
        restoreTask = task
        await task.value
        restoreTask = nil
    }

    func start(roomID: String, duration: Duration) async -> Result<Void, LiveLocationServiceError> {
        guard !isStarting else {
            MXLog.error("A live location share is already starting")
            return .failure(.startFailed)
        }
        isStarting = true
        defer { isStarting = false }

        guard locationProvider.authorization == .authorized else {
            MXLog.info("Can't start a live location share without location access")
            return .failure(.noLocationAccess)
        }
        await restoreTask?.value
        await stop()

        // Started first so Core Location warms up while the share is created.
        startReceivingUpdates()
        guard let roomProxy = await roomProvider(roomID) else {
            MXLog.error("Can't start a live location share: room \(roomID) unavailable")
            stopReceivingUpdates()
            return .failure(.startFailed)
        }

        switch await roomProxy.startLiveLocationShare(duration: duration) {
        case .success(let eventID):
            let endsAt = now().addingTimeInterval(duration / .seconds(1))
            store.save(LiveLocationShareRecord(roomID: roomID, eventID: eventID, endsAt: endsAt))
            MXLog.info("Live location share started in \(roomID)")
            begin(ActiveShare(roomID: roomID, roomProxy: roomProxy, eventID: eventID, endsAt: endsAt))
            return .success(())
        case .failure:
            // The error isn't logged: its description could echo location data.
            MXLog.error("Starting a live location share in \(roomID) failed")
            stopReceivingUpdates()
            return .failure(.startFailed)
        }
    }

    func stop() async {
        await restoreTask?.value
        guard let share = activeShare else { return }
        endLocally(share)
        MXLog.info("Stopping the live location share in \(share.roomID)")

        for attempt in 1...2 {
            if case .success = await share.roomProxy.stopLiveLocationShare() { return }
            MXLog.error("Stopping the live location share failed (attempt \(attempt))")
        }
    }

    // MARK: - Private

    private func performRestore() async {
        guard activeShare == nil, let record = store.load() else { return }
        guard record.endsAt > now() else {
            MXLog.info("The saved live location share has expired, not resuming")
            store.clear()
            return
        }
        guard let roomProxy = await roomProvider(record.roomID) else {
            MXLog.info("Room \(record.roomID) isn't available yet, keeping the saved live location share")
            return
        }
        guard locationProvider.authorization == .authorized else {
            MXLog.info("No location access, stopping the saved live location share")
            await abandon(record, in: roomProxy)
            return
        }

        let status = await savedShareStatus(record, in: roomProxy)
        guard activeShare == nil, store.load() == record else { return }

        switch status {
        case .live:
            MXLog.info("Resuming the live location share in \(record.roomID)")
            startReceivingUpdates()
            begin(ActiveShare(roomID: record.roomID, roomProxy: roomProxy, eventID: record.eventID, endsAt: record.endsAt))
        case .ended, .replaced:
            MXLog.info("The saved live location share is no longer ours to resume")
            store.clear()
        case .unknown:
            // Otherwise it would stay live on the server, with a stale location and nothing to stop it.
            MXLog.info("The room's live shares didn't load in time, stopping the saved live location share")
            await abandon(record, in: roomProxy)
        }
    }

    /// Best effort: if the stop fails, the share still expires on its own.
    private func abandon(_ record: LiveLocationShareRecord, in roomProxy: RoomLocationProxyProtocol) async {
        store.clear()
        if case .failure = await roomProxy.stopLiveLocationShare() {
            MXLog.error("Stopping the saved live location share in \(record.roomID) failed")
        }
    }

    private func begin(_ share: ActiveShare) {
        activeShare = share
        publishState()
        sendIfDue()
    }

    /// Ends the share on this device. The SDK side is left to the caller.
    private func endLocally(_ share: ActiveShare) {
        guard share === activeShare else { return }
        activeShare = nil
        timerTask?.cancel()
        timerTask = nil
        stopReceivingUpdates()
        store.clear()
        publishState()
    }

    private func startReceivingUpdates() {
        guard updatesCancellable == nil else { return }
        updatesCancellable = locationProvider.updatesPublisher.sink { [weak self] fix in
            self?.handle(fix)
        }
        locationProvider.startUpdates()
    }

    private func stopReceivingUpdates() {
        updatesCancellable?.cancel()
        updatesCancellable = nil
        latestFix = nil
        locationProvider.stopUpdates()
    }

    private func handle(_ fix: GeoURI) {
        latestFix = fix
        sendIfDue()
    }

    private func handleOwnBeaconInfo(_ info: OwnBeaconInfo) {
        guard !info.isLive, let share = activeShare, info.eventID == share.eventID else { return }
        MXLog.info("The live location share in \(share.roomID) was stopped elsewhere")
        endLocally(share)
    }

    private func sendIfDue() {
        defer { scheduleTimer() }
        guard let share = activeShare, !share.isSending, let fix = latestFix,
              let dueDate = nextSendDate(for: share), dueDate <= now() else { return }

        share.isSending = true
        share.lastAttemptDate = now()
        Task { [weak self] in
            let result = await share.roomProxy.sendLiveLocation(fix)
            self?.handleSendResult(result, of: fix, for: share)
        }
    }

    private func handleSendResult(_ result: Result<Void, LocationProxyError>, of fix: GeoURI, for share: ActiveShare) {
        share.isSending = false
        guard share === activeShare else { return }

        switch result {
        case .success:
            share.sentCount += 1
            share.lastSentFix = fix
            share.lastAttemptFailed = false
            share.consecutiveFailures = 0
            MXLog.info("Live location update sent (#\(share.sentCount))")
        case .failure:
            // The error isn't logged: its description could echo the coordinates.
            share.lastAttemptFailed = true
            share.consecutiveFailures += 1
            MXLog.error("Sending a live location update failed (\(share.consecutiveFailures) in a row)")
        }
        publishState()
        sendIfDue()
    }

    /// Movement or a failed attempt makes the next update due after the minimum interval; otherwise the keep-alive.
    private func nextSendDate(for share: ActiveShare) -> Date? {
        guard let latestFix else { return nil }
        guard let lastAttemptDate = share.lastAttemptDate else { return .distantPast }

        let hasMoved = share.lastSentFix.map { Self.distance(from: $0, to: latestFix) >= Self.minimumDistance } ?? true
        let interval = share.lastAttemptFailed || hasMoved ? Self.minimumInterval : Self.keepAliveInterval
        return lastAttemptDate.addingTimeInterval(interval / .seconds(1))
    }

    /// One timer at a time, firing at the next update or at the share's end, whichever comes first.
    private func scheduleTimer() {
        timerTask?.cancel()
        timerTask = nil
        guard let share = activeShare else { return }

        var deadline = share.endsAt
        if !share.isSending, let dueDate = nextSendDate(for: share) {
            deadline = min(deadline, dueDate)
        }
        let sleep = makeSleep(.seconds(max(0, deadline.timeIntervalSince(now()))))
        timerTask = Task { [weak self] in
            do { try await sleep() } catch { return }
            guard !Task.isCancelled, let self else { return }
            // Cleared first so ending the share below doesn't cancel this task mid-call.
            timerTask = nil
            await timerFired()
        }
    }

    private func timerFired() async {
        guard let share = activeShare else { return }
        if now() >= share.endsAt {
            MXLog.info("The live location share in \(share.roomID) expired")
            await stop()
        } else {
            sendIfDue()
        }
    }

    /// Waits for the room's live shares to include one of ours, or gives up after `restoreTimeout`.
    private func savedShareStatus(_ record: LiveLocationShareRecord, in roomProxy: RoomLocationProxyProtocol) async -> SavedShareStatus {
        let ownUserID = ownUserID, now = now
        let sleep = makeSleep(Self.restoreTimeout)
        return await withCheckedContinuation { continuation in
            let lookup = OneShotLookup(continuation)
            // The initial snapshot is only sent when non-empty, and arrives after a hop to the main actor.
            lookup.attach(roomProxy.liveLocationsPublisher.sink { summaries in
                let ownShares = summaries.filter { $0.userID == ownUserID }
                if let saved = ownShares.first(where: { $0.beaconID == record.eventID }) {
                    lookup.finish(saved.endDate > now() ? .live : .ended)
                } else if !ownShares.isEmpty {
                    lookup.finish(.replaced)
                }
            })
            lookup.attach(Task {
                try? await sleep()
                lookup.finish(.unknown)
            })
        }
    }

    private func publishState() {
        let state: LiveLocationState = if let activeShare {
            .sharing(roomID: activeShare.roomID, endsAt: activeShare.endsAt,
                     isPaused: activeShare.consecutiveFailures >= Self.maxFailuresBeforePause)
        } else {
            .idle
        }
        guard state != stateSubject.value else { return }
        stateSubject.send(state)
    }

    /// Captures the deadline now, so a timer that starts running late still fires on time.
    private static func sleep(on clock: some Clock<Duration>, for duration: Duration) -> @Sendable () async throws -> Void {
        let deadline = clock.now.advanced(by: duration)
        return { try await clock.sleep(until: deadline, tolerance: nil) }
    }

    private static func distance(from origin: GeoURI, to destination: GeoURI) -> CLLocationDistance {
        CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
    }
}

/// What the room's live shares say about the share saved before a relaunch.
private enum SavedShareStatus {
    case live
    case ended
    /// We share from another device now; stopping would end that share.
    case replaced
    /// The room's shares didn't load in time.
    case unknown
}

/// Resolves a continuation once, then drops its subscription and timeout.
private final class OneShotLookup {
    private var continuation: CheckedContinuation<SavedShareStatus, Never>?
    private var cancellable: AnyCancellable?
    private var timeoutTask: Task<Void, Never>?

    init(_ continuation: CheckedContinuation<SavedShareStatus, Never>) {
        self.continuation = continuation
    }

    func attach(_ cancellable: AnyCancellable) {
        if continuation == nil {
            cancellable.cancel()
        } else {
            self.cancellable = cancellable
        }
    }

    func attach(_ timeoutTask: Task<Void, Never>) {
        if continuation == nil {
            timeoutTask.cancel()
        } else {
            self.timeoutTask = timeoutTask
        }
    }

    func finish(_ status: SavedShareStatus) {
        guard let continuation else { return }
        self.continuation = nil
        cancellable?.cancel()
        cancellable = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation.resume(returning: status)
    }
}
