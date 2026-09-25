//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import MatrixRustSDK

// sourcery: AutoMockable
protocol RoomSummaryProviderProtocol: AnyObject {
    /// DMs and groups (no spaces, no invites), ordered by the SDK (most recent first).
    var roomsPublisher: AnyPublisher<[RoomSummary], Never> { get }
    func start() async
}

final class RoomSummaryProvider: RoomSummaryProviderProtocol {
    private static let filter: RoomListEntriesDynamicFilterKind = .all(filters: [.nonSpace, .joined, .deduplicateVersions])
    private static let pageSize: UInt32 = 200

    private let roomListService: RoomListService
    /// `nil` until the first list arrives, so the chats screen can show a loading state.
    private let roomsSubject = CurrentValueSubject<[RoomSummary]?, Never>(nil)

    private var rooms: [Room] = []
    private var summariesByID: [String: RoomSummary] = [:]
    private var controller: RoomListDynamicEntriesController?
    private var entriesHandle: TaskHandle?
    private var refreshTask: Task<Void, Never>?

    var roomsPublisher: AnyPublisher<[RoomSummary], Never> {
        roomsSubject.compactMap { $0 }.eraseToAnyPublisher()
    }

    init(roomListService: RoomListService) {
        self.roomListService = roomListService
    }

    deinit {
        entriesHandle?.cancel()
        refreshTask?.cancel()
    }

    func start() async {
        guard entriesHandle == nil else { return }

        do {
            let roomList = try await roomListService.allRooms()
            let listener = SDKListener<[RoomListEntriesUpdate]>.onMainActor { [weak self] updates in
                self?.handle(updates)
            }
            let result = roomList.entriesWithDynamicAdapters(pageSize: Self.pageSize, listener: listener)
            controller = result.controller()
            entriesHandle = result.entriesStream()
            _ = controller?.setFilter(kind: Self.filter)
        } catch {
            MXLog.error("Failed starting the room list: \(error)")
        }
    }

    private func handle(_ updates: [RoomListEntriesUpdate]) {
        var touchedIDs = Set<String>()
        for update in updates {
            rooms.apply(ListDiff(update) { room in
                touchedIDs.insert(room.id())
                return room
            })
        }

        let snapshot = rooms
        let previousTask = refreshTask
        // Chained so refreshes apply in order; each only rebuilds the rooms that changed.
        refreshTask = Task { [weak self] in
            await previousTask?.value
            await self?.refreshSummaries(for: snapshot, touchedIDs: touchedIDs)
        }
    }

    private func refreshSummaries(for rooms: [Room], touchedIDs: Set<String>) async {
        for room in rooms {
            let id = room.id()
            guard touchedIDs.contains(id) || summariesByID[id] == nil else { continue }
            do {
                summariesByID[id] = try await RoomSummary(roomInfo: room.roomInfo(), latestEvent: room.latestEvent())
            } catch {
                MXLog.error("Failed loading room info for \(id): \(error)")
            }
        }

        let liveIDs = Set(rooms.map { $0.id() })
        summariesByID = summariesByID.filter { liveIDs.contains($0.key) }
        roomsSubject.send(rooms.compactMap { summariesByID[$0.id()] })
    }
}
