//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import AetherXWatch
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
        harness.confirm("!a")

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
        harness.confirm("!a")

        try await waitUntil { harness.room("!a").sendLiveLocationReceivedInvocations == [.home] }
    }

    @Test
    func theFirstUpdateWaitsForTheSyncedShareToBeLive() async throws {
        let harness = Harness()
        _ = await harness.service.start(roomID: "!a", duration: .seconds(900))
        harness.updates.send(.home)
        // An older share of ours going live isn't the new one.
        harness.ownBeaconInfo.send(OwnBeaconInfo(roomID: "!a", eventID: "$older", isLive: true))

        // Held back until then, for 30 s at most (a send would move the timer to the share's end, then 3 min).
        try await waitUntil { harness.clock.deadlines == [.seconds(30)] }
        #expect(harness.service.state == .sharing(roomID: "!a", endsAt: harness.date(900), isPaused: false))

        harness.confirm("!a")

        try await waitUntil { harness.room("!a").sendLiveLocationReceivedInvocations == [.home] }
    }

    @Test
    func theFirstUpdateIsSentAnywayAfter30Seconds() async throws {
        let harness = Harness()
        _ = await harness.service.start(roomID: "!a", duration: .seconds(900))
        harness.updates.send(.home)
        try await waitUntil { harness.clock.deadlines == [.seconds(30)] }

        harness.clock.advance(by: .seconds(30))

        try await waitUntil { harness.room("!a").sendLiveLocationReceivedInvocations == [.home] }
    }

    @Test
    func aSameRoomRestartWaitsForItsOwnShare() async throws {
        let harness = try await Harness.sharing()
        harness.room("!a").startLiveLocationShareDurationReturnValue = .success("$beacon-!a-2")

        _ = await harness.service.start(roomID: "!a", duration: .seconds(900))
        harness.updates.send(.home.movedNorth(metres: 100))
        // Until sync delivers the new share, the SDK would attach updates to the old one.
        harness.ownBeaconInfo.send(OwnBeaconInfo(roomID: "!a", eventID: "$beacon-!a", isLive: true))

        try await waitUntil { harness.clock.deadlines == [.seconds(30)] }
        harness.confirm("!a", eventID: "$beacon-!a-2")

        try await waitUntil { harness.room("!a").sendLiveLocationCallsCount == 2 }
        #expect(harness.room("!a").sendLiveLocationReceivedInvocations == [.home, .home.movedNorth(metres: 100)])
    }

    @Test
    func notReadyFailuresPauseOnceTheConfirmationWaitIsOver() async throws {
        let harness = Harness()
        harness.room("!a").sendLiveLocationReturnValue = .failure(.beaconNotReady)
        _ = await harness.service.start(roomID: "!a", duration: .seconds(900))
        harness.updates.send(.home)

        // Nothing goes out before 30 s, so every attempt after that counts: sync never delivered the share.
        for attempt in 1...2 {
            try await waitUntil { harness.clock.deadlines == [.seconds(30 * attempt)] }
            harness.clock.advance(by: .seconds(30))
            try await waitUntil { harness.room("!a").sendLiveLocationCallsCount == attempt }
        }
        try await waitUntil { harness.clock.deadlines == [.seconds(90)] }
        #expect(harness.service.state == .sharing(roomID: "!a", endsAt: harness.date(900), isPaused: false))

        harness.clock.advance(by: .seconds(30))

        try await waitUntil { harness.service.state == .sharing(roomID: "!a", endsAt: harness.date(900), isPaused: true) }
        #expect(harness.room("!a").sendLiveLocationCallsCount == 3)
    }

    @Test
    func movingLessThan20MetresDoesNotSend() async throws {
        let harness = try await Harness.sharing()

        harness.clock.advance(by: .seconds(60))
        harness.updates.send(.home.movedNorth(metres: 10))
        // Had the 10 m fix gone out, this one would wait another 30 s and the check below would fail.
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
        // Only the latest fix goes out at 30 s, so an early send would show up as an extra invocation.
        harness.clock.advance(by: .seconds(20))
        try await waitUntil { harness.room("!a").sendLiveLocationCallsCount == 2 }
        #expect(harness.room("!a").sendLiveLocationReceivedInvocations == [.home, .home.movedNorth(metres: 60)])
    }

    @Test
    func sendsAKeepAliveEvery3MinutesWhenStill() async throws {
        let harness = try await Harness.sharing()

        // The next update is timed for 3 min after the last.
        try await waitUntil { harness.clock.deadlines == [.seconds(180)] }
        harness.clock.advance(by: .seconds(180))
        try await waitUntil { harness.room("!a").sendLiveLocationCallsCount == 2 }
        try await waitUntil { harness.clock.deadlines == [.seconds(360)] }
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
    func expiresEvenWithoutAnyFix() async throws {
        let harness = Harness()
        _ = await harness.service.start(roomID: "!a", duration: .seconds(900))
        harness.confirm("!a")
        try await waitUntil { harness.clock.deadlines == [.seconds(900)] }

        harness.clock.advance(by: .seconds(900))

        try await waitUntil { harness.service.state == .idle }
        try await waitUntil { harness.room("!a").stopLiveLocationShareCallsCount == 1 }
        #expect(harness.room("!a").sendLiveLocationCalled == false)
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

        // Nothing can send once the share has ended: no fixes arrive and no timer is left.
        #expect(harness.updatesSubscriberCount == 0)
        #expect(harness.clock.sleeperCount == 0)
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
    func aStopBeforeTheShareIsLiveIsRetriedOnceItIs() async throws {
        let harness = Harness()
        _ = await harness.service.start(roomID: "!a", duration: .seconds(900))
        // The SDK has nothing to stop until sync delivers the new share.
        harness.room("!a").stopLiveLocationShareReturnValue = .failure(.beaconNotReady)

        let stopping = Task { await harness.service.stop() }
        try await waitUntil { harness.room("!a").stopLiveLocationShareCallsCount == 1 }
        #expect(harness.service.state == .idle)
        try await waitUntil { harness.clock.deadlines == [.seconds(30)] }
        harness.room("!a").stopLiveLocationShareReturnValue = .success(())
        harness.confirm("!a")
        await stopping.value

        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 2)
    }

    @Test
    func aRestoredShareDoesNotWaitToRetryAStop() async throws {
        let harness = Harness()
        harness.store.record = LiveLocationShareRecord(roomID: "!a", eventID: "$beacon-!a", endsAt: harness.date(600))
        harness.liveLocations("!a").send([.own(beaconID: "$beacon-!a", endDate: harness.date(600))])
        await harness.service.restore()
        harness.room("!a").stopLiveLocationShareReturnValue = .failure(.beaconNotReady)

        // Already synced, so there's no confirmation to wait for: both attempts go straight out.
        let stopping = Task { await harness.service.stop() }
        try await waitUntil { harness.room("!a").stopLiveLocationShareCallsCount == 2 }
        #expect(harness.clock.deadlines.isEmpty)
        harness.clock.advance(by: .seconds(30))
        await stopping.value

        #expect(harness.service.state == .idle)
    }

    @Test
    func stopAwaitsAnInFlightRetriedStop() async throws {
        let harness = Harness()
        _ = await harness.service.start(roomID: "!a", duration: .seconds(900))
        harness.room("!a").stopLiveLocationShareReturnValue = .failure(.beaconNotReady)
        let gate = AsyncGate()
        let firstStop = Task { await harness.service.stop() }
        try await waitUntil { harness.clock.deadlines == [.seconds(30)] }
        harness.room("!a").stopLiveLocationShareClosure = {
            await gate.wait()
            return .success(())
        }
        harness.confirm("!a")
        try await waitUntil { harness.room("!a").stopLiveLocationShareCallsCount == 2 }

        // E.g. signing out: must not reach logout while the retried stop is still in flight.
        var isStopped = false
        let secondStop = Task {
            await harness.service.stop()
            isStopped = true
        }
        await runQueuedMainActorWork()
        #expect(isStopped == false)

        await gate.open()
        await secondStop.value
        await firstStop.value
        #expect(isStopped)
    }

    @Test
    func aStopRetryGivesUpAfter30Seconds() async throws {
        let harness = Harness()
        _ = await harness.service.start(roomID: "!a", duration: .seconds(900))
        harness.room("!a").stopLiveLocationShareReturnValue = .failure(.beaconNotReady)

        let stopping = Task { await harness.service.stop() }
        try await waitUntil { harness.clock.deadlines == [.seconds(30)] }
        harness.clock.advance(by: .seconds(30))
        await stopping.value
        harness.confirm("!a")

        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 1)
    }

    @Test
    func aNewShareInTheSameRoomDropsAPendingStopRetry() async throws {
        let harness = Harness()
        _ = await harness.service.start(roomID: "!a", duration: .seconds(900))
        harness.room("!a").stopLiveLocationShareReturnValue = .failure(.beaconNotReady)
        let stopping = Task { await harness.service.stop() }
        try await waitUntil { harness.clock.deadlines == [.seconds(30)] }

        // The new share replaces the old one (same state key), so a late stop would only end the new one.
        harness.room("!a").startLiveLocationShareDurationReturnValue = .success("$beacon-!a-2")
        _ = await harness.service.start(roomID: "!a", duration: .seconds(900))
        await stopping.value
        harness.confirm("!a")

        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 1)
        #expect(harness.service.state == .sharing(roomID: "!a", endsAt: harness.date(900), isPaused: false))
    }

    @Test
    func losingLocationAccessEndsTheShare() async throws {
        let harness = try await Harness.sharing()

        harness.locationProvider.authorization = .denied
        harness.authorization.send(.denied)

        try await waitUntil { harness.service.state == .idle }
        try await waitUntil { harness.room("!a").stopLiveLocationShareCallsCount == 1 }
        #expect(harness.locationProvider.stopUpdatesCallsCount == 1)
        #expect(harness.store.record == nil)
    }

    /// Signing out stops before logging out, so a share still starting must not come up afterwards.
    @Test
    func stopDuringAStartEndsTheNewShare() async throws {
        let harness = Harness()
        let gate = AsyncGate()
        harness.room("!a").startLiveLocationShareDurationClosure = { _ in
            await gate.wait()
            return .success("$beacon-!a")
        }
        let starting = Task { await harness.service.start(roomID: "!a", duration: .seconds(900)) }
        try await waitUntil { harness.room("!a").startLiveLocationShareDurationCalled }

        let stopping = Task { await harness.service.stop() }
        await runQueuedMainActorWork()
        await gate.open()
        await stopping.value

        #expect(await starting.value.failure == nil)
        #expect(harness.service.state == .idle)
        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 1)
        #expect(harness.store.record == nil)
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
        harness.confirm("!b")
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
        // Our share was replaced by one started on another device, which stopping would end.
        harness.liveLocations("!a").send([.own(beaconID: "$newer", endDate: harness.date(900))])

        await harness.service.restore()

        #expect(harness.service.state == .idle)
        #expect(harness.store.record == nil)
        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 0)
        #expect(harness.locationProvider.startUpdatesCalled == false)
    }

    @Test
    func stopsTheSavedShareWhenTheRoomsSharesDontLoadInTime() async throws {
        let harness = Harness()
        harness.store.record = LiveLocationShareRecord(roomID: "!a", eventID: "$beacon-!a", endsAt: harness.date(600))

        let restoring = Task { await harness.service.restore() }
        try await waitUntil { harness.clock.sleeperCount == 1 }
        harness.clock.advance(by: .seconds(10))
        await restoring.value

        #expect(harness.service.state == .idle)
        #expect(harness.store.record == nil)
        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 1)
        #expect(harness.locationProvider.startUpdatesCalled == false)
    }

    @Test
    func keepsTheSavedShareUntilTheRoomIsAvailable() async {
        let harness = Harness()
        let record = LiveLocationShareRecord(roomID: "!a", eventID: "$beacon-!a", endsAt: harness.date(600))
        harness.store.record = record
        harness.unavailableRoomIDs = ["!a"]

        await harness.service.restore()

        #expect(harness.service.state == .idle)
        #expect(harness.store.record == record)

        harness.unavailableRoomIDs = []
        harness.liveLocations("!a").send([.own(beaconID: "$beacon-!a", endDate: harness.date(600))])
        await harness.service.restore()

        #expect(harness.service.state == .sharing(roomID: "!a", endsAt: harness.date(600), isPaused: false))
    }

    @Test
    func stopsTheSavedShareWithoutLocationAccess() async {
        let harness = Harness()
        harness.store.record = LiveLocationShareRecord(roomID: "!a", eventID: "$beacon-!a", endsAt: harness.date(600))
        harness.liveLocations("!a").send([.own(beaconID: "$beacon-!a", endDate: harness.date(600))])
        harness.locationProvider.authorization = .denied

        await harness.service.restore()

        #expect(harness.service.state == .idle)
        #expect(harness.store.record == nil)
        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 1)
        #expect(harness.locationProvider.startUpdatesCalled == false)
    }

    @Test
    func doesNotStopAReplacedShareWithoutLocationAccess() async {
        let harness = Harness()
        harness.store.record = LiveLocationShareRecord(roomID: "!a", eventID: "$beacon-!a", endsAt: harness.date(600))
        harness.liveLocations("!a").send([.own(beaconID: "$newer", endDate: harness.date(900))])
        harness.locationProvider.authorization = .denied

        await harness.service.restore()

        #expect(harness.store.record == nil)
        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 0)
    }

    @Test
    func startingStopsASavedShareThatWasNotResumed() async {
        let harness = Harness()
        harness.store.record = LiveLocationShareRecord(roomID: "!a", eventID: "$beacon-!a", endsAt: harness.date(600))

        let result = await harness.service.start(roomID: "!b", duration: .seconds(900))

        #expect(result.failure == nil)
        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 1)
        #expect(harness.store.record?.roomID == "!b")
    }

    @Test
    func restoringDuringAStartStopsTheSavedShare() async throws {
        let harness = Harness()
        harness.store.record = LiveLocationShareRecord(roomID: "!a", eventID: "$beacon-!a", endsAt: harness.date(600))
        harness.unavailableRoomIDs = ["!a"]
        await harness.service.restore()
        #expect(harness.store.record?.roomID == "!a")

        let gate = AsyncGate()
        harness.room("!b").startLiveLocationShareDurationClosure = { _ in
            await gate.wait()
            return .success("$beacon-!b")
        }
        let starting = Task { await harness.service.start(roomID: "!b", duration: .seconds(900)) }
        try await waitUntil { harness.room("!b").startLiveLocationShareDurationCalled }

        // The room list loads meanwhile and the session restores again.
        harness.unavailableRoomIDs = []
        harness.liveLocations("!a").send([.own(beaconID: "$beacon-!a", endDate: harness.date(600))])
        await harness.service.restore()
        await gate.open()
        let result = await starting.value

        #expect(result.failure == nil)
        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 1)
        #expect(harness.service.state == .sharing(roomID: "!b", endsAt: harness.date(900), isPaused: false))
        #expect(harness.store.record?.roomID == "!b")
        harness.updates.send(.home)
        harness.confirm("!b")
        try await waitUntil { harness.room("!b").sendLiveLocationCallsCount == 1 }
        #expect(harness.room("!a").sendLiveLocationCallsCount == 0)
    }

    @Test
    func startingDuringARestoreStopsTheRestoredShare() async throws {
        let harness = Harness()
        harness.store.record = LiveLocationShareRecord(roomID: "!a", eventID: "$beacon-!a", endsAt: harness.date(600))

        // The room's shares haven't loaded yet, so the restore is waiting.
        let restoring = Task { await harness.service.restore() }
        try await waitUntil { harness.clock.sleeperCount == 1 }
        let starting = Task { await harness.service.start(roomID: "!b", duration: .seconds(900)) }
        await runQueuedMainActorWork()
        #expect(harness.room("!b").startLiveLocationShareDurationCalled == false)

        harness.liveLocations("!a").send([.own(beaconID: "$beacon-!a", endDate: harness.date(600))])
        await restoring.value
        let result = await starting.value

        #expect(result.failure == nil)
        #expect(harness.room("!a").stopLiveLocationShareCallsCount == 1)
        #expect(harness.room("!b").startLiveLocationShareDurationCallsCount == 1)
        #expect(harness.service.state == .sharing(roomID: "!b", endsAt: harness.date(900), isPaused: false))
        #expect(harness.store.record?.roomID == "!b")
    }

    @Test
    func threeFailuresPauseThenASuccessResumes() async throws {
        let harness = Harness()
        harness.room("!a").sendLiveLocationReturnValue = .failure(.sdkError("failed"))
        _ = await harness.service.start(roomID: "!a", duration: .seconds(900))
        harness.updates.send(.home)
        harness.confirm("!a")

        try await waitUntil { harness.room("!a").sendLiveLocationCallsCount == 1 }
        harness.clock.advance(by: .seconds(30))
        try await waitUntil { harness.room("!a").sendLiveLocationCallsCount == 2 }
        // Timed once the second failure is handled.
        try await waitUntil { harness.clock.deadlines == [.seconds(60)] }
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
        #expect(harness.locationProvider.startUpdatesCallsCount == 1)
        #expect(harness.locationProvider.stopUpdatesCallsCount == 1)
    }

    @Test
    func startFailsWhenTheRoomIsUnavailable() async {
        let harness = Harness()

        let result = await harness.service.start(roomID: "!missing", duration: .seconds(900))

        #expect(result.failure == .startFailed)
        #expect(harness.service.state == .idle)
        #expect(harness.locationProvider.startUpdatesCallsCount == 1)
        #expect(harness.locationProvider.stopUpdatesCallsCount == 1)
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

    /// Lets tasks already queued on the main actor (e.g. a `Task` calling into the service) run up to their
    /// first suspension. Checks that something did *not* happen use deterministic signals instead (clock
    /// deadlines, subscriptions), since the mocks' calls hop off the main actor.
    private func runQueuedMainActorWork() async {
        for _ in 0..<10 {
            await Task.yield()
        }
    }
}

private final class Harness {
    static let ownUserID = "@me:x"

    let clock = TestClock()
    let startDate = Date(timeIntervalSince1970: 1_700_000_000)
    let locationProvider = LocationProviderMock()
    let updates = PassthroughSubject<GeoURI, Never>()
    let authorization = CurrentValueSubject<LocationAuthorization, Never>(.authorized)
    let ownBeaconInfo = PassthroughSubject<OwnBeaconInfo, Never>()
    let store = InMemoryLiveLocationShareStore()
    var unavailableRoomIDs: Set<String> = []
    private(set) var requestedRoomIDs: [String] = []
    private(set) var updatesSubscriberCount = 0
    private var rooms: [String: RoomLocationProxyMock] = [:]
    private var liveLocationSubjects: [String: CurrentValueSubject<[LiveLocationSummary], Never>] = [:]
    private(set) var service: LiveLocationService!

    init() {
        locationProvider.authorization = .authorized
        locationProvider.authorizationPublisher = authorization.eraseToAnyPublisher()
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

        locationProvider.updatesPublisher = updates
            .handleEvents(receiveSubscription: { [weak self] _ in self?.updatesSubscriberCount += 1 },
                          receiveCancel: { [weak self] in self?.updatesSubscriberCount -= 1 })
            .eraseToAnyPublisher()

        let clock = clock, startDate = startDate
        service = LiveLocationService(ownUserID: Self.ownUserID,
                                      locationProvider: locationProvider,
                                      roomProvider: { [unowned self] roomID in
                                          requestedRoomIDs.append(roomID)
                                          return unavailableRoomIDs.contains(roomID) ? nil : rooms[roomID]
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
        harness.confirm("!a")
        try await waitUntil { harness.room("!a").sendLiveLocationCallsCount == 1 }
        return harness
    }

    /// Sync delivering our new share as live, which the SDK needs before it can send updates or stop it.
    func confirm(_ roomID: String, eventID: String? = nil) {
        ownBeaconInfo.send(OwnBeaconInfo(roomID: roomID, eventID: eventID ?? "$beacon-\(roomID)", isLive: true))
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
