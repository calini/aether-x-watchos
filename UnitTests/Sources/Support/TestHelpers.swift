//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import Testing

/// A one-shot gate that lets a test hold an async closure open until it explicitly releases it.
actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

/// Polls a main-actor condition, yielding between checks (fails after ~2 s).
func waitUntil(_ condition: @MainActor () -> Bool) async throws {
    for _ in 0..<200 {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Condition not met in time")
}

/// A settable `now` and a manual tick, for view models that re-evaluate live shares' expiry over time.
final class ExpiryClock {
    var now = Date(timeIntervalSince1970: 1_700_000_000)
    private let subject = PassthroughSubject<Void, Never>()

    var ticks: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    func tick() {
        subject.send()
    }
}
