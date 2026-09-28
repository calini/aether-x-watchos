//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import AetherXWatch
import Foundation
import Testing

struct VoiceMessageRecorderTests {
    @Test
    func publishesElapsedAndLevel() async throws {
        let harness = try await Harness.recording()
        #expect(harness.recorder.state == .recording(elapsed: 0, level: 0, isNearLimit: false))

        harness.backend.averagePowerReturnValue = -25
        try await harness.advance(to: 0.1)
        #expect(harness.recorder.state == .recording(elapsed: 0.1, level: 0.5, isNearLimit: false))

        harness.backend.averagePowerReturnValue = -80
        try await harness.advance(to: 0.2)
        #expect(harness.recorder.state == .recording(elapsed: 0.2, level: 0, isNearLimit: false))

        harness.backend.averagePowerReturnValue = 3
        try await harness.advance(to: 0.3)
        #expect(harness.recorder.state == .recording(elapsed: 0.3, level: 1, isNearLimit: false))
    }

    @Test
    func warnsOnceAt4m30() async throws {
        let harness = try await Harness.recording()

        try await harness.advance(to: 269.9)
        #expect(harness.hapticCount == 0)
        #expect(harness.recorder.state == .recording(elapsed: 269.9, level: 0, isNearLimit: false))

        try await harness.advance(to: 270)
        #expect(harness.hapticCount == 1)
        #expect(harness.recorder.state == .recording(elapsed: 270, level: 0, isNearLimit: true))

        try await harness.advance(to: 280)
        #expect(harness.hapticCount == 1)
        #expect(harness.recorder.state == .recording(elapsed: 280, level: 0, isNearLimit: true))
    }

    @Test
    func stopsAt5Minutes() async throws {
        let harness = try await Harness.recording()

        try await harness.advance(to: 299.9)
        #expect(harness.backend.stopCallsCount == 0)

        try await harness.advance(to: 300)
        guard case let .stopped(message) = harness.recorder.state else {
            Issue.record("Expected a stopped recording")
            return
        }
        #expect(message.duration == 300)
        #expect(harness.backend.stopCallsCount == 1)
        #expect(harness.clock.sleeperCount == 0)
        #expect(FileManager.default.fileExists(atPath: message.pcmURL.path(percentEncoded: false)))
        harness.removeRecording()
    }

    @Test
    func shortRecordingsAreDiscarded() async throws {
        let harness = try await Harness.recording()
        try await harness.advance(to: 0.9)

        harness.recorder.stop()

        #expect(harness.recorder.state == .discarded)
        #expect(harness.backend.stopCallsCount == 1)
        #expect(!harness.recordingExists)
    }

    @Test
    func interruptionStopsAndKeeps() async throws {
        let harness = try await Harness.recording()
        harness.backend.averagePowerReturnValue = -10
        try await harness.advance(to: 2)

        harness.interruptions.send()

        guard case let .stopped(message) = harness.recorder.state else {
            Issue.record("Expected a stopped recording")
            return
        }
        #expect(message.duration == 2)
        #expect(message.pcmURL == harness.recordingURL)
        #expect(message.waveform.count == 100)
        #expect(harness.recordingExists)
        #expect(harness.backend.stopCallsCount == 1)
        #expect(harness.audioSession.deactivateCallsCount == 1)
        #expect(harness.clock.sleeperCount == 0)
        harness.removeRecording()
    }

    @Test
    func interruptionAfterTheRecorderResetKeepsTheLastElapsed() async throws {
        let harness = try await Harness.recording()
        try await harness.advance(to: 2)
        harness.backend.currentTime = 0

        harness.interruptions.send()

        guard case let .stopped(message) = harness.recorder.state else {
            Issue.record("Expected a stopped recording")
            return
        }
        #expect(message.duration == 2)
        #expect(harness.recordingExists)
        harness.removeRecording()
    }

    @Test
    func stoppingTwiceOrInterruptingAfterStopDoesNothing() async throws {
        let harness = try await Harness.recording()
        try await harness.advance(to: 2)
        harness.recorder.stop()
        let stoppedState = harness.recorder.state

        harness.recorder.stop()
        harness.interruptions.send()

        #expect(harness.recorder.state == stoppedState)
        #expect(harness.backend.stopCallsCount == 1)
        #expect(harness.audioSession.deactivateCallsCount == 1)
        #expect(harness.recordingExists)
        harness.removeRecording()
    }

    @Test
    func nonFinitePowerIsSilence() async throws {
        let harness = try await Harness.recording()

        harness.backend.averagePowerReturnValue = -.infinity
        try await harness.advance(to: 0.1)
        #expect(harness.recorder.state == .recording(elapsed: 0.1, level: 0, isNearLimit: false))

        harness.backend.averagePowerReturnValue = .nan
        try await harness.advance(to: 0.2)
        #expect(harness.recorder.state == .recording(elapsed: 0.2, level: 0, isNearLimit: false))
        harness.recorder.cancel()
    }

    @Test
    func startWhileRecordingFails() async throws {
        let harness = try await Harness.recording()

        #expect(await harness.recorder.start().error == .failed)
        #expect(harness.backend.startUrlCallsCount == 1)
        #expect(harness.recorder.state == .recording(elapsed: 0, level: 0, isNearLimit: false))
        harness.recorder.cancel()
    }

    @Test
    func releasingMidRecordingDeletesTheFile() async throws {
        let harness = try await Harness.recording()
        try await harness.advance(to: 2)

        harness.releaseRecorder()

        #expect(harness.backend.stopCallsCount == 1)
        #expect(harness.audioSession.deactivateCallsCount == 1)
        #expect(!harness.recordingExists)
    }

    @Test
    func cancelDeletesAndGoesIdle() async throws {
        let harness = try await Harness.recording()
        try await harness.advance(to: 5)

        harness.recorder.cancel()

        #expect(harness.recorder.state == .idle)
        #expect(harness.backend.stopCallsCount == 1)
        #expect(!harness.recordingExists)
        #expect(harness.clock.sleeperCount == 0)
    }

    @Test
    func cancelAfterStopDeletesTheRecording() async throws {
        let harness = try await Harness.recording()
        try await harness.advance(to: 5)
        harness.recorder.stop()

        harness.recorder.cancel()

        #expect(harness.recorder.state == .idle)
        #expect(!harness.recordingExists)
        #expect(harness.audioSession.deactivateCallsCount == 1)
    }

    @Test
    func deniedPermissionFails() async {
        let harness = Harness(isPermissionGranted: false)

        let result = await harness.recorder.start()

        #expect(result.error == .permissionDenied)
        #expect(harness.recorder.state == .idle)
        #expect(!harness.audioSession.activateForRecordingCalled)
        #expect(!harness.backend.startUrlCalled)
    }

    @Test
    func backendFailureFailsAndReleasesTheSession() async {
        let harness = Harness()
        harness.backend.startUrlThrowableError = CancellationError()

        let result = await harness.recorder.start()

        #expect(result.error == .failed)
        #expect(harness.recorder.state == .failed)
        #expect(harness.audioSession.deactivateCallsCount == 1)
        #expect(harness.clock.sleeperCount == 0)
    }

    @Test
    func activationFailureFailsAndReleasesTheSession() async {
        let harness = Harness()
        harness.audioSession.activateForRecordingThrowableError = CancellationError()

        let result = await harness.recorder.start()

        #expect(result.error == .failed)
        #expect(harness.recorder.state == .failed)
        #expect(harness.audioSession.deactivateCallsCount == 1)
        #expect(!harness.backend.startUrlCalled)
    }

    @Test
    func cancelDuringThePermissionPromptDoesNotRecord() async {
        let harness = Harness()
        let gate = AsyncGate()
        harness.audioSession.requestRecordPermissionClosure = {
            await gate.wait()
            return true
        }

        let start = Task { await harness.recorder.start() }
        try? await waitUntil { harness.audioSession.requestRecordPermissionCalled }
        harness.recorder.cancel()
        await gate.open()

        #expect(await start.value.error == .failed)
        #expect(harness.recorder.state == .idle)
        #expect(!harness.backend.startUrlCalled)
    }

    @Test
    func waveformIsReducedTo100Values() async throws {
        #expect(VoiceMessageRecorder.waveform(from: []) == Array(repeating: 0, count: 100))
        #expect(VoiceMessageRecorder.waveform(from: [0.3]) == Array(repeating: 0.3, count: 100))
        let alternating = (0..<200).map { Float($0 % 2) }
        #expect(VoiceMessageRecorder.waveform(from: alternating) == Array(repeating: 0.5, count: 100))
        let steps = (0..<300).map { Float($0 / 3) / 128 }
        #expect(VoiceMessageRecorder.waveform(from: steps) == (0..<100).map { Float($0) / 128 })

        let harness = try await Harness.recording()
        var tick = 0
        harness.backend.averagePowerClosure = {
            tick += 1
            return tick <= 100 ? -50 : 0
        }
        try await harness.advance(to: 20)
        harness.recorder.stop()

        guard case let .stopped(message) = harness.recorder.state else {
            Issue.record("Expected a stopped recording")
            return
        }
        #expect(message.waveform == Array(repeating: 0, count: 50) + Array(repeating: 1, count: 50))
        harness.removeRecording()
    }

    @Test
    func aShortRecordingIsStretchedAcrossTheWholeWaveform() {
        let ramp = (0..<12).map { Float($0) / 11 }

        let waveform = VoiceMessageRecorder.waveform(from: ramp)

        #expect(waveform.count == 100)
        // Interpolated end to end, rather than padded with a flat tail.
        for (index, level) in waveform.enumerated() {
            #expect(abs(level - Float(index) / 99) < 0.0001)
        }
        let twoLevels = VoiceMessageRecorder.waveform(from: [0.2, 0.4])
        #expect(twoLevels.first == 0.2)
        #expect(twoLevels.last == 0.4)
        #expect(abs(twoLevels[50] - 0.301) < 0.001)
    }

    @Test
    func aLongRecordingAveragesItsSamplesIntoBuckets() {
        let samples = (0..<1234).map { Float($0 % 7) / 6 }

        let waveform = VoiceMessageRecorder.waveform(from: samples)

        #expect(waveform.count == 100)
        for bucket in 0..<100 {
            let slice = samples[bucket * 1234 / 100..<(bucket + 1) * 1234 / 100]
            #expect(abs(waveform[bucket] - slice.reduce(0, +) / Float(slice.count)) < 0.0001)
        }
    }

    @Test
    func sessionIsReleasedOnStopAndCancel() async throws {
        let harness = try await Harness.recording()
        #expect(harness.audioSession.activateForRecordingCallsCount == 1)
        #expect(harness.audioSession.deactivateCallsCount == 0)
        try await harness.advance(to: 3)
        harness.recorder.stop()
        #expect(harness.audioSession.deactivateCallsCount == 1)
        harness.removeRecording()

        #expect(await harness.recorder.start().error == nil)
        #expect(harness.audioSession.activateForRecordingCallsCount == 2)
        harness.recorder.cancel()
        #expect(harness.audioSession.deactivateCallsCount == 2)
    }
}

// MARK: - Helpers

private final class Harness {
    let clock = TestClock()
    let backend = AudioRecorderBackendMock()
    let audioSession = AudioSessionProxyMock()
    let interruptions = PassthroughSubject<Void, Never>()
    private(set) var hapticCount = 0
    private(set) var recorder: VoiceMessageRecorder!

    var recordingURL: URL? {
        backend.startUrlReceivedUrl
    }

    var recordingExists: Bool {
        guard let recordingURL else { return false }
        return FileManager.default.fileExists(atPath: recordingURL.path(percentEncoded: false))
    }

    init(isPermissionGranted: Bool = true) {
        audioSession.requestRecordPermissionReturnValue = isPermissionGranted
        backend.underlyingInterruptions = interruptions.eraseToAnyPublisher()
        backend.currentTime = 0
        backend.averagePowerReturnValue = -50
        backend.startUrlClosure = { url in
            FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: Data([1, 2, 3]))
        }
        recorder = VoiceMessageRecorder(audioSession: audioSession, backend: backend, clock: clock, haptic: { [weak self] in
            self?.hapticCount += 1
        })
    }

    static func recording() async throws -> Harness {
        let harness = Harness()
        try #require(await harness.recorder.start().error == nil)
        try await waitUntil { harness.clock.sleeperCount == 1 }
        return harness
    }

    /// Moves the recorded time and the clock to `seconds`, then waits for the recorder to catch up on its ticks.
    func advance(to seconds: TimeInterval) async throws {
        let target = Duration.milliseconds(Int((seconds * 1000).rounded()))
        backend.currentTime = seconds
        clock.advance(by: target - clock.now.offset)
        try await waitUntil {
            guard case .recording = recorder.state else { return true }
            return clock.deadlines.first.map { $0 > target } ?? false
        }
    }

    func releaseRecorder() {
        recorder = nil
    }

    func removeRecording() {
        guard let recordingURL else { return }
        try? FileManager.default.removeItem(at: recordingURL)
    }
}

private extension Result where Success == Void {
    var error: Failure? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}
