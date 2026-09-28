//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import AetherXWatch
import Foundation
import MatrixRustSDK

/// A `ClientProxyMock` wired to publisher fixtures, shared by the chats and settings screen tests.
struct Setup {
    let rooms = CurrentValueSubject<[RoomSummary], Never>([])
    let syncState = CurrentValueSubject<SyncState, Never>(.running)
    let verification = CurrentValueSubject<SessionVerification, Never>(.verified)
    let actions = PassthroughSubject<ClientProxyAction, Never>()
    let clientProxy = ClientProxyMock()
    let locationProvider = LocationProviderMock()
    let liveLocationService = LiveLocationServiceMock()
    let liveLocationState = CurrentValueSubject<LiveLocationState, Never>(.idle)
    let audioSession = AudioSessionProxyMock()
    let voiceMessagePlayer = VoiceMessagePlayerMock()
    /// Named calls in the order they happened, for tests that check sequencing.
    let calls = Recorder<String>()

    var locationServices: LocationServices {
        LocationServices(locationProvider: locationProvider, liveLocationService: liveLocationService)
    }

    var voiceMessageServices: VoiceMessageServices {
        VoiceMessageServices(audioSession: audioSession, player: voiceMessagePlayer)
    }

    init() {
        let provider = RoomSummaryProviderMock()
        provider.roomsPublisher = rooms.eraseToAnyPublisher()
        clientProxy.roomSummaryProvider = provider
        clientProxy.syncStatePublisher = syncState.eraseToAnyPublisher()
        clientProxy.verificationStatePublisher = verification.eraseToAnyPublisher()
        clientProxy.actionsPublisher = actions.eraseToAnyPublisher()
        clientProxy.ownBeaconInfoPublisher = Empty().eraseToAnyPublisher()
        clientProxy.userID = "@me:example.org"
        clientProxy.loadDisplayNameReturnValue = "Me"
        locationProvider.authorization = .authorized
        locationProvider.authorizationPublisher = Just(.authorized).eraseToAnyPublisher()
        liveLocationService.state = .idle
        liveLocationService.statePublisher = liveLocationState.eraseToAnyPublisher()
        voiceMessagePlayer.state = .idle
        voiceMessagePlayer.statePublisher = Just(.idle).eraseToAnyPublisher()
    }
}

/// Collects values from closures that can't mutate the test's own state.
final class Recorder<Value> {
    var values: [Value] = []
}

extension SessionVerificationControllerProxyMock {
    /// A controller that emits nothing and whose calls all succeed.
    @MainActor static var idle: SessionVerificationControllerProxyMock {
        let mock = SessionVerificationControllerProxyMock()
        mock.actionsPublisher = Empty().eraseToAnyPublisher()
        mock.requestDeviceVerificationReturnValue = .success(())
        mock.startSasVerificationReturnValue = .success(())
        mock.approveVerificationReturnValue = .success(())
        mock.declineVerificationReturnValue = .success(())
        mock.cancelVerificationReturnValue = .success(())
        return mock
    }
}

extension RoomSummary {
    static func fixture(id: String, name: String, isDirect: Bool = true, unreadCount: Int = 0) -> RoomSummary {
        RoomSummary(id: id, name: name, avatarURL: nil, isDirect: isDirect, lastMessage: "Hello", lastMessageDate: .now,
                    unreadCount: unreadCount, hasUnreadMentions: false, isMarkedUnread: false)
    }
}

extension EventItem {
    static func fixture(eventID: String?, body: String = "Hello", sendState: SendState = .sent, isOwn: Bool = false) -> EventItem {
        fixture(eventID: eventID, body: .text(AttributedString(body)), sendState: sendState, isOwn: isOwn)
    }

    static func fixture(eventID: String?, body: TimelineItemBody, sendState: SendState = .sent, isOwn: Bool = false) -> EventItem {
        EventItem(itemID: eventID.map { .eventId(eventId: $0) } ?? .transactionId(transactionId: "txn"),
                  eventID: eventID,
                  senderID: "@bob:example.org",
                  senderName: "Bob",
                  isOwn: isOwn,
                  date: Date(timeIntervalSince1970: 1_700_000_000),
                  body: body,
                  replyTo: nil,
                  reactions: [],
                  isEdited: false,
                  sendState: sendState,
                  canBeRepliedTo: true)
    }
}

extension LiveLocationSummary {
    static func fixture(userID: String, beaconID: String, geoURI: GeoURI?) -> LiveLocationSummary {
        LiveLocationSummary(userID: userID, beaconID: beaconID, startDate: .now, endDate: .now.addingTimeInterval(900),
                            lastGeoURI: geoURI, lastUpdate: .now)
    }
}

extension AetherXWatch.TimelineItem {
    static func event(_ id: String, body: String, isOwn: Bool = false) -> AetherXWatch.TimelineItem {
        AetherXWatch.TimelineItem(id: id, kind: .event(.fixture(eventID: "$\(id)", body: body, isOwn: isOwn)))
    }
}
