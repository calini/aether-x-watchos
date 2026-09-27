//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Combine
import CryptoKit

enum VoicePlaybackState: Equatable {
    case idle
    /// Downloading and decoding.
    case preparing(id: String)
    /// `progress` is in 0…1.
    case playing(id: String, progress: Double, elapsed: TimeInterval)
    case paused(id: String, progress: Double, elapsed: TimeInterval)
    /// Downloading or decoding failed; playing the same ID again retries.
    case failed(id: String)
}

extension VoicePlaybackState {
    /// The message this state is about, if any.
    var id: String? {
        switch self {
        case .idle: nil
        case .preparing(let id), .playing(let id, _, _), .paused(let id, _, _), .failed(let id): id
        }
    }
}

// sourcery: AutoMockable
/// Plays received voice messages, one at a time.
protocol VoiceMessagePlayerProtocol: AnyObject {
    var statePublisher: AnyPublisher<VoicePlaybackState, Never> { get }
    var state: VoicePlaybackState { get }

    /// Resumes `id` if it's paused; otherwise stops whatever is playing, prepares `id` and plays it from the start.
    func play(id: String, source: MediaSourceProxy) async
    func pause()
    /// Stops, and releases the audio session if playback took it.
    func stop()
}

// sourcery: AutoMockable
/// An `AVAudioPlayer`, behind a protocol for tests.
protocol AudioPlaybackBackend: AnyObject {
    var duration: TimeInterval { get }
    var currentTime: TimeInterval { get }
    /// Called on the main actor when playback reaches the end.
    var finishHandler: (() -> Void)? { get set }

    func play() -> Bool
    func pause()
    func stop()
}

/// One per session. Decoded messages are cached, so replaying one skips the download and the decode.
final class VoiceMessagePlayer: VoiceMessagePlayerProtocol {
    private static let progressInterval = Duration.milliseconds(100)

    private let loadContent: (MediaSourceProxy) async -> Data?
    private let audioSession: AudioSessionProxyProtocol
    private let cache: VoiceMessageCache
    private let makeAudioPlayer: (URL) throws -> AudioPlaybackBackend
    private let makeTickSleeper: () -> @Sendable (Int) async throws -> Void
    private let stateSubject = CurrentValueSubject<VoicePlaybackState, Never>(.idle)
    /// The message that's playing or paused, and its decoded file.
    private var current: (id: String, backend: AudioPlaybackBackend, fileURL: URL)?
    /// Bumped by `stop`, so a prepare still running knows it was abandoned.
    private var generation = 0
    /// The session is shared with the recorder, so it's only released if playback took it.
    private var isHoldingSession = false
    private var progressTask: Task<Void, Never>?

    var state: VoicePlaybackState { stateSubject.value }
    var statePublisher: AnyPublisher<VoicePlaybackState, Never> { stateSubject.eraseToAnyPublisher() }

    /// - Parameter loadContent: Downloads (and decrypts) the Ogg Opus file.
    init(loadContent: @escaping (MediaSourceProxy) async -> Data?,
         audioSession: AudioSessionProxyProtocol,
         cacheDirectory: URL = URL.cachesDirectory.appending(path: "VoiceMessages", directoryHint: .isDirectory),
         cacheLimitBytes: Int = 20_000_000,
         makeAudioPlayer: @escaping (URL) throws -> AudioPlaybackBackend = { try AVAudioPlayerBackend(url: $0) },
         clock: some Clock<Duration> = ContinuousClock()) {
        self.loadContent = loadContent
        self.audioSession = audioSession
        cache = VoiceMessageCache(directory: cacheDirectory, limitBytes: cacheLimitBytes)
        self.makeAudioPlayer = makeAudioPlayer
        makeTickSleeper = { Self.tickSleeper(on: clock) }
    }

    isolated deinit {
        stop()
    }

    func play(id: String, source: MediaSourceProxy) async {
        switch state {
        case .preparing(id), .playing(id, _, _):
            return
        case .paused(id, _, _):
            if let backend = current?.backend {
                startPlayback(id: id, backend: backend)
                return
            }
        default:
            break
        }

        stop()
        stateSubject.send(.preparing(id: id))
        let preparingGeneration = generation
        let fileURL = await prepare(source, generation: preparingGeneration)
        guard preparingGeneration == generation else { return }
        guard let fileURL else {
            fail(id)
            return
        }

        let backend: AudioPlaybackBackend
        do {
            backend = try makeAudioPlayer(fileURL)
        } catch {
            MXLog.error("Opening the decoded voice message failed")
            fail(id)
            return
        }
        let backendID = ObjectIdentifier(backend)
        backend.finishHandler = { [weak self] in self?.finishPlaying(backendID: backendID) }
        current = (id, backend, fileURL)
        startPlayback(id: id, backend: backend)
    }

    func pause() {
        guard case .playing(let id, _, _) = state, let backend = current?.backend else { return }
        backend.pause()
        stopProgressUpdates()
        releaseSession()
        stateSubject.send(.paused(id: id, progress: Self.progress(of: backend), elapsed: backend.currentTime))
    }

    func stop() {
        generation += 1
        stopProgressUpdates()
        current?.backend.stop()
        current = nil
        releaseSession()
        if state != .idle {
            stateSubject.send(.idle)
        }
    }

    // MARK: - Private

    /// The decoded file, from the cache or else downloaded and decoded into it.
    /// Returns `nil` as soon as `stop` or another `play` supersedes `preparingGeneration`, skipping the decode.
    private func prepare(_ source: MediaSourceProxy, generation preparingGeneration: Int) async -> URL? {
        let cache = cache
        let key = VoiceMessageCache.key(for: source.url)
        if let fileURL = await Task.detached(operation: { cache.cachedFile(for: key) }).value {
            MXLog.info("Voice message found in the cache")
            return fileURL
        }

        guard let oggData = await loadContent(source) else {
            MXLog.error("Downloading the voice message failed")
            return nil
        }
        guard preparingGeneration == generation else { return nil }
        guard oggData.count <= VoiceMessageDecoder.maximumOggBytes else {
            MXLog.error("The voice message is too large to play: \(oggData.count) bytes")
            return nil
        }

        guard let fileURL = await Task.detached(operation: { try? cache.store(oggData, for: key) }).value else {
            MXLog.error("Decoding the voice message failed")
            return nil
        }
        // A superseded prepare leaves eviction to the next store, so it can't remove the message playing now.
        guard preparingGeneration == generation else { return nil }
        let keptURLs = [fileURL, current?.fileURL].compactMap(\.self)
        await Task.detached { cache.evict(keeping: keptURLs) }.value
        return fileURL
    }

    private func startPlayback(id: String, backend: AudioPlaybackBackend) {
        do {
            try audioSession.activateForPlayback()
        } catch {
            MXLog.error("Activating the audio session for playback failed")
            fail(id)
            return
        }
        isHoldingSession = true

        guard backend.play() else {
            MXLog.error("Starting voice message playback failed")
            fail(id)
            return
        }
        stateSubject.send(.playing(id: id, progress: Self.progress(of: backend), elapsed: backend.currentTime))
        startProgressUpdates()
    }

    /// `backendID` names the player that finished: a late callback from one that was since replaced is ignored.
    private func finishPlaying(backendID: ObjectIdentifier) {
        guard let current, ObjectIdentifier(current.backend) == backendID else { return }
        MXLog.info("Voice message playback finished")
        stopProgressUpdates()
        self.current = nil
        releaseSession()
        stateSubject.send(.idle)
    }

    private func fail(_ id: String) {
        stopProgressUpdates()
        current?.backend.stop()
        current = nil
        releaseSession()
        stateSubject.send(.failed(id: id))
    }

    private func releaseSession() {
        guard isHoldingSession else { return }
        isHoldingSession = false
        audioSession.deactivate()
    }

    private func startProgressUpdates() {
        stopProgressUpdates()
        let sleep = makeTickSleeper()
        progressTask = Task { [weak self] in
            var tick = 1
            while !Task.isCancelled {
                do { try await sleep(tick) } catch { return }
                guard !Task.isCancelled, let self, case .playing(let id, _, _) = self.state, let backend = self.current?.backend else { return }
                self.stateSubject.send(.playing(id: id, progress: Self.progress(of: backend), elapsed: backend.currentTime))
                tick += 1
            }
        }
    }

    private func stopProgressUpdates() {
        progressTask?.cancel()
        progressTask = nil
    }

    private static func progress(of backend: AudioPlaybackBackend) -> Double {
        guard backend.duration > 0 else { return 0 }
        return min(max(backend.currentTime / backend.duration, 0), 1)
    }

    /// Sleeps until tick `n` from now, so ticks don't drift when one runs late.
    private static func tickSleeper(on clock: some Clock<Duration>) -> @Sendable (Int) async throws -> Void {
        let start = clock.now
        return { tick in try await clock.sleep(until: start.advanced(by: progressInterval * tick), tolerance: nil) }
    }
}

/// Decoded voice messages, named by a hash of their media URL and trimmed to `limitBytes`, least recently used first.
/// Blocking file work: call off the main actor.
nonisolated struct VoiceMessageCache: Sendable {
    private static let partialFileLifetime: TimeInterval = 5 * 60

    let directory: URL
    let limitBytes: Int

    static func key(for mediaURL: String) -> String {
        SHA256.hash(data: Data(mediaURL.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// The decoded file, if it's cached, marked as just used.
    func cachedFile(for key: String) -> URL? {
        let fileURL = fileURL(for: key)
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return nil }
        try? FileManager.default.setAttributes([.modificationDate: Date.now], ofItemAtPath: fileURL.path())
        return fileURL
    }

    /// Decodes `oggData` into the cache.
    func store(_ oggData: Data, for key: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = fileURL(for: key)
        // Decoded under a temporary name, so a half-written file is never taken for a cached one.
        let partialURL = directory.appending(path: "\(key)-\(UUID().uuidString).partial")
        defer { try? FileManager.default.removeItem(at: partialURL) }

        _ = try VoiceMessageDecoder.decode(oggData: oggData, to: partialURL)
        do {
            try FileManager.default.moveItem(at: partialURL, to: fileURL)
        } catch where FileManager.default.fileExists(atPath: fileURL.path()) {
            // Another store of the same message got there first; its file is just as good.
        }
        return fileURL
    }

    /// Removes the least recently used files, other than `keptURLs`, until the cache fits its limit,
    /// and what decodes cut short by the app being killed left behind.
    func evict(keeping keptURLs: [URL], now: Date = .now) {
        let keptNames = Set(keptURLs.map(\.lastPathComponent))
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys)) else { return }
        let allFiles = urls.map { url in
            let values = try? url.resourceValues(forKeys: keys)
            return (url: url, date: values?.contentModificationDate ?? .distantPast, size: values?.fileSize ?? 0)
        }

        // A decode still running keeps writing to its file, so only files left untouched for a while are stale.
        let stalePartials = allFiles.filter { $0.url.pathExtension == "partial" && now.timeIntervalSince($0.date) > Self.partialFileLifetime }
        stalePartials.forEach { try? FileManager.default.removeItem(at: $0.url) }
        if !stalePartials.isEmpty {
            MXLog.info("Removed \(stalePartials.count) unfinished voice message decodes")
        }

        let files = allFiles
            .filter { $0.url.pathExtension == "caf" }
            .sorted { $0.date < $1.date }

        var totalSize = files.reduce(0) { $0 + $1.size }
        var evictedCount = 0
        for file in files where totalSize > limitBytes && !keptNames.contains(file.url.lastPathComponent) {
            try? FileManager.default.removeItem(at: file.url)
            totalSize -= file.size
            evictedCount += 1
        }
        if evictedCount > 0 {
            MXLog.info("Evicted \(evictedCount) cached voice messages")
        }
    }

    private func fileURL(for key: String) -> URL {
        directory.appending(path: "\(key).caf")
    }
}

/// Plays a file with `AVAudioPlayer`.
final class AVAudioPlayerBackend: NSObject, AudioPlaybackBackend, AVAudioPlayerDelegate {
    private let player: AVAudioPlayer

    var finishHandler: (() -> Void)?
    var duration: TimeInterval { player.duration }
    var currentTime: TimeInterval { player.currentTime }

    init(url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        super.init()
        player.delegate = self
    }

    func play() -> Bool {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func stop() {
        player.stop()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in finishHandler?() }
    }
}
