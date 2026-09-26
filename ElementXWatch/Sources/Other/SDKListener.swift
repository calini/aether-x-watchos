//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

/// A helper class that can be passed as this listener for SDK callbacks.
///
/// To use this you'll need to add a conformance to the required listener
/// protocol with a specialisation for the type it listens for.
final nonisolated class SDKListener<T>: Sendable {
    fileprivate let onUpdateClosure: @Sendable (T) -> Void

    /// Creates a new listener.
    /// - Parameter onUpdateClosure: A closure that will be called whenever a new value is available.
    init(_ onUpdateClosure: @escaping @Sendable (T) -> Void) {
        self.onUpdateClosure = onUpdateClosure
    }
}

nonisolated extension SDKListener where T: Sendable {
    /// Creates a new listener that delivers its updates on the main actor in FIFO order,
    /// guaranteeing one in-flight update at a time.
    ///
    /// The SDK calls listeners from arbitrary threads, use this whenever the updates
    /// need to touch main actor state. The internal stream (and so the long-lived task
    /// consuming it) ends when the listener is released.
    /// - Parameter onUpdate: A closure that will be called on the main actor whenever a new value is available.
    static func onMainActor(_ onUpdate: @escaping @MainActor (T) -> Void) -> SDKListener<T> {
        let (stream, continuation) = AsyncStream<T>.makeStream()

        Task { @MainActor in
            for await value in stream {
                onUpdate(value)
            }
        }

        // The wrapper is owned by the listener's closure, so when the SDK releases the listener
        // (its subscription handle being dropped) the wrapper deinits and finishes the stream,
        // ending the consumer task above. Deiniting the continuation alone does *not* terminate
        // the stream (see SE-0406), which would otherwise leak the task.
        let continuationWrapper = StreamContinuationWrapper(continuation)
        return SDKListener { value in
            continuationWrapper.continuation.yield(value)
        }
    }
}

/// Owns an `AsyncStream.Continuation` and finishes its stream when released.
private final nonisolated class StreamContinuationWrapper<Element: Sendable>: Sendable {
    let continuation: AsyncStream<Element>.Continuation

    init(_ continuation: AsyncStream<Element>.Continuation) {
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
    }
}

// MARK: - Conformances used by the watch

nonisolated extension SDKListener: SyncServiceStateObserver where T == SyncServiceState {
    func onUpdate(state: SyncServiceState) { onUpdateClosure(state) }
}

nonisolated extension SDKListener: RoomListEntriesListener where T == [RoomListEntriesUpdate] {
    func onUpdate(roomEntriesUpdate: [RoomListEntriesUpdate]) { onUpdateClosure(roomEntriesUpdate) }
}

nonisolated extension SDKListener: RoomListLoadingStateListener where T == RoomListLoadingState {
    func onUpdate(state: RoomListLoadingState) { onUpdateClosure(state) }
}

nonisolated extension SDKListener: RoomListServiceSyncIndicatorListener where T == RoomListServiceSyncIndicator {
    func onUpdate(syncIndicator: RoomListServiceSyncIndicator) { onUpdateClosure(syncIndicator) }
}

nonisolated extension SDKListener: TimelineListener where T == [TimelineDiff] {
    func onUpdate(diff: [TimelineDiff]) { onUpdateClosure(diff) }
}

nonisolated extension SDKListener: GeneratedQrLoginProgressListener where T == GeneratedQrLoginProgress {
    func onUpdate(state: GeneratedQrLoginProgress) { onUpdateClosure(state) }
}

nonisolated extension SDKListener: SendQueueRoomErrorListener where T == (String, ClientError) {
    func onError(roomId: String, error: ClientError) { onUpdateClosure((roomId, error)) }
}

nonisolated extension SDKListener: VerificationStateListener where T == VerificationState {
    func onUpdate(status: VerificationState) { onUpdateClosure(status) }
}

nonisolated extension SDKListener: LiveLocationsListener where T == [LiveLocationShareUpdate] {
    func onUpdate(updates: [LiveLocationShareUpdate]) { onUpdateClosure(updates) }
}

nonisolated extension SDKListener: BeaconInfoListener where T == BeaconInfoUpdate {
    func onUpdate(update: BeaconInfoUpdate) { onUpdateClosure(update) }
}

nonisolated extension SDKListener {
    /// Delivers a value to the listener's closure (for wrappers that aren't SDK listener protocols).
    func forward(_ value: T) { onUpdateClosure(value) }
}
