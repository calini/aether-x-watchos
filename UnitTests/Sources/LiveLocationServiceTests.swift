//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementXWatch
import Foundation
import Testing

struct LiveLocationServiceTests {
    @Test
    func startingSendsAnInitialUpdateAndPublishesSharing() async throws {
        let harness = Harness()
        var states: [LiveLocationState] = []
        let cancellable = harness.service.statePublisher.sink { states.append($0) }

        let result = await harness.service.start(roomID: "!a", duration: .seconds(900))
        harness.updates.send(.home)

        #expect(result.failure == nil)
        #expect(harness.service.state == .sharing(roomID: "!a", endsAt: harness.date(900), isPaused: false))
        #expect(states == [.idle, .sharing(roomID: "!a", endsAt: harness.date(900), isPaused: false)])
        #expect(harness.room("!a").startLiveLocationShareDurationReceivedDuration == .seconds(900))
        #expect(harness.locationProvider.startUpdatesCallsCount == 1)
        #expect(harness.store.record == LiveLocationShareRecord(roomID: "!a", eventID: "$beacon-!a", endsAt: harness.date(900)))
        try await waitUntil { harness.room("!a").sendLiveLocationReceivedInvocations == [.home] }
        cancellable.cancel()
    }

    @Test
    func updatesArrivingBeforeTheShareIsLiveAreSentOnceItIs() async throws {
        let harness = Harness()
        let gate = AsyncGate()
        harness.room("!a").startLiveLocationShareDurationClosure = { _ in
            await gate.wait()
            return .success("$beacon-!a")
        }

        let starting = Task { await harness.service.start(roomID: "!a", duration: .seconds(900)) }
        try await waitUntil { harness.room("!a").startLiveLocationShareDurationCalled }
        harness.updates.send(.home)
        await gate.open()
        _ = await starting.value

        try await waitUntil { harness.room("!a").sendLiveLocationReceivedInvocations == [.home] }
    }

    @Test
    func movingLessThan20MetresDoesNotSend() async throws {
        let harness = try await Harness.sharing()

        harness.clock.advance(by: .seconds(60))
        harness.updates.send(.home.movedNorth(metres: 10))
        await settle()
        #expect(harness.room("!a").sendLiveLocationCallsCount == 1)

        harness.updates.send(.home.movedNorth(metres: 30))
        try await waitUntil { harness.room("!a").sendLiveLocationCallsCount == 2 }
        #expect(harness.room("!a").sendLiveLocationReceivedInvocations == [.home, .home.movedNorth(metres: 30)])
    }

    @Test
    func sendsAtMostEvery30Seconds() async throws {
        let harness = try await Harness.sharing()

        harness.clock.advance(by: .seconds(10))
        harness.updates.send(.home.movedNorth(metres: 50))
        // A one-off fix taken elsewhere during the share arrives on the same stream.
        harness.updates.send(.home.movedNorth(metres: 60))
        await settle()
        #expect(harness.room("!a").sendLiveLocationCallsCount == 1)

        harness.clock.advance(by: .seconds(20))
        try await waitUntil { harness.room("!a").sendLiveLocationCallsCount == 2 }
        #expect(harness.room("!a").sendLiveLocationReceivedInvocations == [.home, .home.movedNorth(metres: 60)])
    }

    @Test
    func sendsAKeepAliveEvery3MinutesWhenStill() async throws {
        let harness = try await Harness.sharing()

        harness.clock.advance(by: .seconds(179))
        await settle()
        #expect(harness.room("!a").sendLiveLocationCallsCount == 1)

        harness.clock.advance(by: .seconds(1))
        try await waitUntil { harness.room("!a").sendLiveLocationCallsCount == 2 }
        harness.clock.advance(by: .seconds(180))
        try await waitUntil { harness.room("!a").sendLiveLocationCallsCount == 3 }
        #expect(harness.room("!a").sendLiveLocationReceivedInvocations == [.home, .home, .home])
    }

    @Test
    func stopsAutomaticallyAtExpiry() async throws {
        let harness = try await Harness.sharing()

        harness.clock.advance(by: .seconds(900))

        try await waitUntil { harness.service.state == .idle }
        try await waitUntil { harness.room("!a").stopLiveLocationShareCallsCount == 1 }
        #expect(harness.locationProvider.stopUpdatesCallsCount == 1)
        #expect(harness.store.record == nil)
    }

    @Test
    func stopEndsTheShare() async throws {
        let harness = try await Harness.sharing()

        await harness.service.stop()

        #expect(harness.service.state == .idle)
        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 1)
        #expect(harness.locationProvider.stopUpdatesCallsCount == 1)
        #expect(harness.store.record == nil)

        // Nothing is sent once the share has ended.
        harness.clock.advance(by: .seconds(180))
        harness.updates.send(.home.movedNorth(metres: 100))
        await settle()
        #expect(harness.room("!a").sendLiveLocationCallsCount == 1)
    }

    @Test
    func stopRetriesOnceThenEndsLocally() async throws {
        let harness = try await Harness.sharing()
        harness.room("!a").stopLiveLocationShareReturnValue = .failure(.sdkError("failed"))

        await harness.service.stop()

        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 2)
        #expect(harness.service.state == .idle)
        #expect(harness.locationProvider.stopUpdatesCallsCount == 1)
    }

    @Test
    func startingInAnotherRoomStopsTheFirst() async throws {
        let harness = try await Harness.sharing()

        let result = await harness.service.start(roomID: "!b", duration: .seconds(3600))

        #expect(result.failure == nil)
        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 1)
        #expect(harness.room("!b").startLiveLocationShareDurationCallsCount == 1)
        #expect(harness.service.state == .sharing(roomID: "!b", endsAt: harness.date(3600), isPaused: false))
        #expect(harness.store.record?.roomID == "!b")

        harness.updates.send(.home.movedNorth(metres: 100))
        try await waitUntil { harness.room("!b").sendLiveLocationCallsCount == 1 }
        #expect(harness.room("!a").sendLiveLocationCallsCount == 1)
    }

    @Test
    func stopFromAnotherDeviceEndsTheShare() async throws {
        let harness = try await Harness.sharing()

        harness.ownBeaconInfo.send(OwnBeaconInfo(roomID: "!a", eventID: "$other", isLive: false))
        harness.ownBeaconInfo.send(OwnBeaconInfo(roomID: "!a", eventID: "$beacon-!a", isLive: true))
        #expect(harness.service.state != .idle)

        harness.ownBeaconInfo.send(OwnBeaconInfo(roomID: "!a", eventID: "$beacon-!a", isLive: false))

        try await waitUntil { harness.service.state == .idle }
        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 0)
        #expect(harness.locationProvider.stopUpdatesCallsCount == 1)
        #expect(harness.store.record == nil)
    }

    @Test
    func resumesAnActiveShareAfterRelaunch() async throws {
        let harness = Harness()
        harness.store.record = LiveLocationShareRecord(roomID: "!a", eventID: "$beacon-!a", endsAt: harness.date(600))
        harness.liveLocations("!a").send([.own(beaconID: "$beacon-!a", endDate: harness.date(600)),
                                          .fixture(userID: "@bob:x", beaconID: "$bob", endDate: harness.date(900))])

        await harness.service.restore()

        #expect(harness.service.state == .sharing(roomID: "!a", endsAt: harness.date(600), isPaused: false))
        #expect(harness.locationProvider.startUpdatesCallsCount == 1)
        #expect(harness.room("!a").startLiveLocationShareDurationCalled == false)
        harness.updates.send(.home)
        try await waitUntil { harness.room("!a").sendLiveLocationReceivedInvocations == [.home] }

        harness.clock.advance(by: .seconds(600))
        try await waitUntil { harness.service.state == .idle }
        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 1)
    }

    @Test
    func doesNotResumeAnExpiredShare() async {
        let harness = Harness()
        harness.store.record = LiveLocationShareRecord(roomID: "!a", eventID: "$beacon-!a", endsAt: harness.date(-1))

        await harness.service.restore()

        #expect(harness.service.state == .idle)
        #expect(harness.store.record == nil)
        #expect(harness.requestedRoomIDs.isEmpty)
        #expect(harness.locationProvider.startUpdatesCalled == false)
    }

    @Test
    func doesNotResumeAShareThatIsGone() async throws {
        let harness = Harness()
        harness.store.record = LiveLocationShareRecord(roomID: "!a", eventID: "$beacon-!a", endsAt: harness.date(600))
        // Our share was replaced by one started on another device.
        harness.liveLocations("!a").send([.own(beaconID: "$newer", endDate: harness.date(900))])

        let restoring = Task { await harness.service.restore() }
        try await waitUntil { harness.clock.sleeperCount == 1 }
        harness.clock.advance(by: .seconds(10))
        await restoring.value

        #expect(harness.service.state == .idle)
        #expect(harness.store.record == nil)
        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 0)
        #expect(harness.locationProvider.startUpdatesCalled == false)
    }

    @Test
    func threeFailuresPauseThenASuccessResumes() async throws {
        let harness = Harness()
        harness.room("!a").sendLiveLocationReturnValue = .failure(.sdkError("failed"))
        _ = await harness.service.start(roomID: "!a", duration: .seconds(900))
        harness.updates.send(.home)

        try await waitUntil { harness.room("!a").sendLiveLocationCallsCount == 1 }
        harness.clock.advance(by: .seconds(30))
        try await waitUntil { harness.room("!a").sendLiveLocationCallsCount == 2 }
        await settle()
        #expect(harness.service.state == .sharing(roomID: "!a", endsAt: harness.date(900), isPaused: false))

        harness.clock.advance(by: .seconds(30))
        try await waitUntil { harness.service.state == .sharing(roomID: "!a", endsAt: harness.date(900), isPaused: true) }
        #expect(harness.room("!a").sendLiveLocationCallsCount == 3)

        harness.room("!a").sendLiveLocationReturnValue = .success(())
        harness.clock.advance(by: .seconds(30))
        try await waitUntil { harness.service.state == .sharing(roomID: "!a", endsAt: harness.date(900), isPaused: false) }
        #expect(harness.room("!a").sendLiveLocationReceivedInvocations == [.home, .home, .home, .home])
    }

    @Test
    func startFailureLeavesTheServiceIdle() async {
        let harness = Harness()
        harness.room("!a").startLiveLocationShareDurationReturnValue = .failure(.sdkError("failed"))

        let result = await harness.service.start(roomID: "!a", duration: .seconds(900))

        #expect(result.failure == .startFailed)
        #expect(harness.service.state == .idle)
        #expect(harness.store.record == nil)
        #expect(harness.locationProvider.stopUpdatesCallsCount == harness.locationProvider.startUpdatesCallsCount)
    }

    @Test
    func startFailsWhenTheRoomIsUnavailable() async {
        let harness = Harness()

        let result = await harness.service.start(roomID: "!missing", duration: .seconds(900))

        #expect(result.failure == .startFailed)
        #expect(harness.service.state == .idle)
        #expect(harness.locationProvider.stopUpdatesCallsCount == harness.locationProvider.startUpdatesCallsCount)
    }

    @Test
    func startFailsWithoutLocationAccess() async {
        let harness = Harness()
        harness.locationProvider.authorization = .denied

        let result = await harness.service.start(roomID: "!a", duration: .seconds(900))

        #expect(result.failure == .noLocationAccess)
        #expect(harness.room("!a").startLiveLocationShareDurationCalled == false)
        #expect(harness.locationProvider.startUpdatesCalled == false)
    }

    @Test
    func releasingTheServiceStopsUpdates() async throws {
        var harness: Harness? = try await Harness.sharing()
        let locationProvider = try #require(harness?.locationProvider)

        harness = nil

        #expect(locationProvider.stopUpdatesCallsCount == 1)
    }

    @Test
    func userDefaultsStoreKeepsOneRecordPerUser() throws {
        let suiteName = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let alice = UserDefaultsLiveLocationShareStore(userID: "@alice:x", defaults: defaults)
        let bob = UserDefaultsLiveLocationShareStore(userID: "@bob:x", defaults: defaults)
        let record = LiveLocationShareRecord(roomID: "!a", eventID: "$e", endsAt: Date(timeIntervalSince1970: 1_700_000_000))

        alice.save(record)

        #expect(alice.load() == record)
        #expect(bob.load() == nil)
        alice.clear()
        #expect(alice.load() == nil)
    }

    // MARK: - Helpers

    /// Lets main-actor tasks and the mocks' concurrent calls run, for checks that something did not happen.
    private func settle() async {
        for _ in 0..<10 {
            await Task.yield()
        }
        try? await Task.sleep(for: .milliseconds(5))
    }
}

private final class Harness {
    static let ownUserID = "@me:x"

    let clock = TestClock()
    let startDate = Date(timeIntervalSince1970: 1_700_000_000)
    let locationProvider = LocationProviderMock()
    let updates = PassthroughSubject<GeoURI, Never>()
    let ownBeaconInfo = PassthroughSubject<OwnBeaconInfo, Never>()
    let store = InMemoryLiveLocationShareStore()
    private(set) var requestedRoomIDs: [String] = []
    private var rooms: [String: RoomLocationProxyMock] = [:]
    private var liveLocationSubjects: [String: CurrentValueSubject<[LiveLocationSummary], Never>] = [:]
    private(set) var service: LiveLocationService!

    init() {
        locationProvider.authorization = .authorized
        locationProvider.updatesPublisher = updates.eraseToAnyPublisher()
        for roomID in ["!a", "!b"] {
            let subject = CurrentValueSubject<[LiveLocationSummary], Never>([])
            let room = RoomLocationProxyMock()
            room.roomID = roomID
            room.liveLocationsPublisher = subject.eraseToAnyPublisher()
            room.startLiveLocationShareDurationReturnValue = .success("$beacon-\(roomID)")
            room.sendLiveLocationReturnValue = .success(())
            room.stopLiveLocationShareReturnValue = .success(())
            rooms[roomID] = room
            liveLocationSubjects[roomID] = subject
        }

        let clock = clock, startDate = startDate
        service = LiveLocationService(ownUserID: Self.ownUserID,
                                      locationProvider: locationProvider,
                                      roomProvider: { [unowned self] roomID in
                                          requestedRoomIDs.append(roomID)
                                          return rooms[roomID]
                                      },
                                      ownBeaconInfoPublisher: ownBeaconInfo.eraseToAnyPublisher(),
                                      store: store,
                                      clock: clock,
                                      now: { startDate.addingTimeInterval(TimeInterval(clock.now.offset.components.seconds)) })
    }

    /// A harness sharing in `!a` for 15 minutes, with the initial update to `.home` sent.
    static func sharing() async throws -> Harness {
        let harness = Harness()
        _ = await harness.service.start(roomID: "!a", duration: .seconds(900))
        harness.updates.send(.home)
        try await waitUntil { harness.room("!a").sendLiveLocationCallsCount == 1 }
        return harness
    }

    func room(_ roomID: String) -> RoomLocationProxyMock {
        rooms[roomID]!
    }

    func liveLocations(_ roomID: String) -> CurrentValueSubject<[LiveLocationSummary], Never> {
        liveLocationSubjects[roomID]!
    }

    func date(_ secondsFromStart: TimeInterval) -> Date {
        startDate.addingTimeInterval(secondsFromStart)
    }
}

private final class InMemoryLiveLocationShareStore: LiveLocationShareStoreProtocol {
    var record: LiveLocationShareRecord?

    func load() -> LiveLocationShareRecord? {
        record
    }

    func save(_ record: LiveLocationShareRecord) {
        self.record = record
    }

    func clear() {
        record = nil
    }
}

private extension Result {
    var failure: Failure? {
        guard case .failure(let error) = self else { return nil }
        return error
    }
}

private extension GeoURI {
    static let home = GeoURI(latitude: 51.5, longitude: -0.12, uncertainty: 10)

    func movedNorth(metres: Double) -> GeoURI {
        GeoURI(latitude: latitude + metres / 111_195, longitude: longitude, uncertainty: uncertainty)
    }
}

private extension LiveLocationSummary {
    static func own(beaconID: String, endDate: Date) -> LiveLocationSummary {
        fixture(userID: Harness.ownUserID, beaconID: beaconID, endDate: endDate)
    }

    static func fixture(userID: String, beaconID: String, endDate: Date) -> LiveLocationSummary {
        LiveLocationSummary(userID: userID, beaconID: beaconID, startDate: endDate.addingTimeInterval(-900),
                            endDate: endDate, lastGeoURI: nil, lastUpdate: nil)
    }
}
