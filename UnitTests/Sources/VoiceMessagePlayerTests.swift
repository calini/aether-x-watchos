//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Combine
@testable import ElementXWatch
import MatrixRustSDK
import Testing

struct VoiceMessagePlayerTests {
    @Test
    func preparesAndPlays() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let source = try harness.source("a")

        await harness.player.play(id: "$a", source: source)

        #expect(harness.states.values.contains(.preparing(id: "$a")))
        #expect(harness.player.state == .playing(id: "$a", progress: 0, elapsed: 0))
        #expect(harness.loadedSources == [source])
        #expect(harness.audioSession.activateForPlaybackCallsCount == 1)
        let playedURL = try #require(harness.madeURLs.first)
        #expect(playedURL.deletingLastPathComponent().standardizedFileURL == harness.cacheDirectory.standardizedFileURL)
        #expect(playedURL.pathExtension == "caf")
        let file = try AVAudioFile(forReading: playedURL)
        #expect(abs(Double(file.length) / file.fileFormat.sampleRate - 1) < 0.03)
        #expect(harness.backends.first?.playCallsCount == 1)

        harness.backends[0].currentTime = 0.5
        try await harness.tick()

        #expect(harness.player.state == .playing(id: "$a", progress: 0.5, elapsed: 0.5))
    }

    @Test
    func usesTheCacheSecondTime() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let source = try harness.source("a")

        await harness.player.play(id: "$a", source: source)
        harness.player.stop()
        await harness.player.play(id: "$a", source: source)

        #expect(harness.loadedSources.count == 1)
        #expect(harness.madeURLs.count == 2)
        #expect(harness.madeURLs[0] == harness.madeURLs[1])
        #expect(harness.player.state == .playing(id: "$a", progress: 0, elapsed: 0))
    }

    @Test
    func playingAnotherStopsTheFirst() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }

        try await harness.player.play(id: "$a", source: harness.source("a"))
        try await harness.player.play(id: "$b", source: harness.source("b"))

        #expect(harness.backends.count == 2)
        #expect(harness.backends[0].stopCallsCount == 1)
        #expect(harness.player.state == .playing(id: "$b", progress: 0, elapsed: 0))
        #expect(harness.audioSession.activateForPlaybackCallsCount == 2)
        #expect(harness.audioSession.deactivateCallsCount == 1)
    }

    @Test
    func pauseAndResume() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let source = try harness.source("a")
        await harness.player.play(id: "$a", source: source)
        harness.backends[0].currentTime = 0.25

        harness.player.pause()

        #expect(harness.player.state == .paused(id: "$a", progress: 0.25, elapsed: 0.25))
        #expect(harness.backends[0].pauseCallsCount == 1)
        #expect(harness.audioSession.deactivateCallsCount == 1)
        #expect(harness.clock.sleeperCount == 0)

        await harness.player.play(id: "$a", source: source)

        #expect(harness.player.state == .playing(id: "$a", progress: 0.25, elapsed: 0.25))
        #expect(harness.backends.count == 1)
        #expect(harness.backends[0].playCallsCount == 2)
        #expect(harness.loadedSources.count == 1)
        #expect(harness.audioSession.activateForPlaybackCallsCount == 2)
    }

    @Test
    func endReturnsToIdleAndReleasesSession() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        try await harness.player.play(id: "$a", source: harness.source("a"))
        try await waitUntil { harness.clock.sleeperCount == 1 }

        harness.backends[0].finishHandler?()

        #expect(harness.player.state == .idle)
        #expect(harness.audioSession.deactivateCallsCount == 1)
        try await waitUntil { harness.clock.sleeperCount == 0 }
    }

    @Test
    func aLateFinishFromAnEarlierPlayerIsIgnored() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        try await harness.player.play(id: "$a", source: harness.source("a"))
        let staleFinish = try #require(harness.backends[0].finishHandler)
        try await harness.player.play(id: "$b", source: harness.source("b"))
        let deactivations = harness.audioSession.deactivateCallsCount

        staleFinish()

        #expect(harness.player.state == .playing(id: "$b", progress: 0, elapsed: 0))
        #expect(harness.audioSession.deactivateCallsCount == deactivations)
    }

    @Test
    func stoppingWhenIdleLeavesTheSessionAlone() throws {
        let harness = try Harness()
        defer { harness.removeFiles() }

        // The recorder may be using the shared session, so a stop must only release what the player took.
        harness.player.stop()

        #expect(harness.audioSession.deactivateCallsCount == 0)
    }

    @Test
    func downloadFailureFails() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        harness.content = { _ in nil }

        try await harness.player.play(id: "$a", source: harness.source("a"))

        #expect(harness.player.state == .failed(id: "$a"))
        #expect(!harness.audioSession.activateForPlaybackCalled)
        #expect(harness.madeURLs.isEmpty)
    }

    @Test
    func corruptFileFails() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        harness.content = { _ in Data("not a voice message".utf8) }

        try await harness.player.play(id: "$a", source: harness.source("a"))

        #expect(harness.player.state == .failed(id: "$a"))
        #expect(!harness.audioSession.activateForPlaybackCalled)
        #expect(harness.cachedFiles.isEmpty)
    }

    @Test
    func failedRetriesOnPlay() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let ogg = harness.ogg
        harness.content = { _ in nil }
        let source = try harness.source("a")
        await harness.player.play(id: "$a", source: source)
        #expect(harness.player.state == .failed(id: "$a"))

        harness.content = { _ in ogg }
        await harness.player.play(id: "$a", source: source)

        #expect(harness.player.state == .playing(id: "$a", progress: 0, elapsed: 0))
        #expect(harness.loadedSources.count == 2)
    }

    @Test
    func cacheEvictsOverLimit() async throws {
        // Room for two decoded seconds of 16-bit audio, not three.
        let harness = try Harness(cacheLimitBytes: 250_000)
        defer { harness.removeFiles() }
        let first = try harness.source("a")

        await harness.player.play(id: "$a", source: first)
        try await harness.player.play(id: "$b", source: harness.source("b"))
        #expect(harness.cachedFiles.count == 2)
        // Replaying the first makes the second the least recently used.
        await harness.player.play(id: "$a", source: first)
        try await harness.player.play(id: "$c", source: harness.source("c"))

        #expect(harness.loadedSources.count == 3)
        #expect(harness.cachedFiles == Set([harness.madeURLs[0], harness.madeURLs[3]].map(\.lastPathComponent)))
    }

    @Test
    func aSlowPrepareSupersededByAnotherIsDropped() async throws {
        // Room for one decoded message only, so storing the first would evict the second.
        let harness = try Harness(cacheLimitBytes: 150_000)
        defer { harness.removeFiles() }
        let first = try harness.source("a")
        let gate = harness.gate(first)
        let firstPlay = Task { await harness.player.play(id: "$a", source: first) }
        try await waitUntil { harness.loadedSources.count == 1 }

        try await harness.player.play(id: "$b", source: harness.source("b"))
        gate.open()
        await firstPlay.value

        #expect(harness.player.state == .playing(id: "$b", progress: 0, elapsed: 0))
        #expect(harness.madeURLs.count == 1)
        #expect(harness.cachedFiles == [try #require(harness.madeURLs.first).lastPathComponent])
        #expect(harness.audioSession.activateForPlaybackCallsCount == 1)
    }

    @Test
    func stoppingWhilePreparingDropsIt() async throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let source = try harness.source("a")
        let gate = harness.gate(source)
        let play = Task { await harness.player.play(id: "$a", source: source) }
        try await waitUntil { harness.loadedSources.count == 1 }
        #expect(harness.player.state == .preparing(id: "$a"))

        harness.player.stop()
        gate.open()
        await play.value

        #expect(harness.player.state == .idle)
        #expect(harness.madeURLs.isEmpty)
        #expect(harness.cachedFiles.isEmpty)
        #expect(!harness.audioSession.activateForPlaybackCalled)
    }

    @Test
    func storingAMessageAlreadyCachedKeepsTheCachedFile() throws {
        let harness = try Harness()
        defer { harness.removeFiles() }
        let cache = VoiceMessageCache(directory: harness.cacheDirectory, limitBytes: 20_000_000)
        let key = VoiceMessageCache.key(for: "mxc://example.org/a")

        // As when two stores of the same message race: the second finds the first's file in place.
        let first = try cache.store(harness.ogg, for: key)
        let second = try cache.store(harness.ogg, for: key)

        #expect(second == first)
        #expect(harness.cachedFiles == [first.lastPathComponent])
        #expect(try FileManager.default.contentsOfDirectory(atPath: harness.cacheDirectory.path()).count == 1)
    }

    // MARK: - Helpers

    /// Holds a download until `open()`.
    private final class Gate {
        private var isOpen = false
        private var continuation: CheckedContinuation<Void, Never>?

        func wait() async {
            guard !isOpen else { return }
            await withCheckedContinuation { continuation = $0 }
        }

        func open() {
            isOpen = true
            continuation?.resume()
            continuation = nil
        }
    }

    private final class Harness {
        let cacheDirectory = FileManager.default.temporaryDirectory.appending(path: "VoiceMessagePlayerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let audioSession = AudioSessionProxyMock()
        let clock = TestClock()
        let ogg: Data
        let states = Recorder<VoicePlaybackState>()
        var content: (MediaSourceProxy) -> Data?
        private(set) var loadedSources: [MediaSourceProxy] = []
        private(set) var madeURLs: [URL] = []
        private(set) var backends: [AudioPlaybackBackendMock] = []
        private var gates: [String: Gate] = [:]
        private(set) var player: VoiceMessagePlayer!
        private var cancellable: AnyCancellable?

        var cachedFiles: Set<String> {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path())) ?? []
            return Set(names.filter { $0.hasSuffix(".caf") })
        }

        init(cacheLimitBytes: Int = 20_000_000) throws {
            ogg = try Self.encodedTone()
            let ogg = ogg
            content = { _ in ogg }
            player = VoiceMessagePlayer(loadContent: { [unowned self] source in
                                            loadedSources.append(source)
                                            await gates[source.url]?.wait()
                                            return content(source)
                                        },
                                        audioSession: audioSession,
                                        cacheDirectory: cacheDirectory,
                                        cacheLimitBytes: cacheLimitBytes,
                                        makeAudioPlayer: { [unowned self] url in
                                            madeURLs.append(url)
                                            let backend = AudioPlaybackBackendMock()
                                            backend.duration = 1
                                            backend.currentTime = 0
                                            backend.playReturnValue = true
                                            backends.append(backend)
                                            return backend
                                        },
                                        clock: clock)
            cancellable = player.statePublisher.sink { [states] in states.values.append($0) }
        }

        func source(_ name: String) throws -> MediaSourceProxy {
            try MediaSourceProxy(source: MediaSource.fromUrl(url: "mxc://example.org/\(name)"))
        }

        func gate(_ source: MediaSourceProxy) -> Gate {
            let gate = Gate()
            gates[source.url] = gate
            return gate
        }

        /// Fires the next 0.1 s progress update.
        func tick() async throws {
            try await waitUntil { clock.sleeperCount == 1 }
            let count = states.values.count
            clock.advance(by: .milliseconds(100))
            try await waitUntil { states.values.count > count }
        }

        func removeFiles() {
            player.stop()
            try? FileManager.default.removeItem(at: cacheDirectory)
        }

        private static func encodedTone() throws -> Data {
            let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).caf")
            let format = OpusCodec.pcmFormat
            let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000))
            let samples = try #require(buffer.floatChannelData)
            buffer.frameLength = 48000
            for index in 0..<48000 {
                samples[0][index] = 0.5 * sin(2 * .pi * 440 * Float(index) / 48000)
            }
            try file.write(from: buffer)
            file.close()
            let message = try VoiceMessageEncoder.encode(recordingAt: url)
            defer { [url, message.fileURL].forEach { try? FileManager.default.removeItem(at: $0) } }
            return try Data(contentsOf: message.fileURL)
        }
    }
}
