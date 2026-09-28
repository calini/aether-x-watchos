//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
import Combine
import WatchKit

nonisolated enum VoiceRecorderState: Equatable, Sendable {
    case idle
    /// `level` is the input level in 0…1.
    case recording(elapsed: TimeInterval, level: Float, isNearLimit: Bool)
    /// The file is kept until the caller takes it, or calls `cancel()`, which deletes it.
    case stopped(RecordedVoiceMessage)
    /// Shorter than the minimum duration; the file is already deleted.
    case discarded
    case failed
}

nonisolated struct RecordedVoiceMessage: Equatable, Sendable {
    /// 48 kHz mono Float32 PCM in a CAF file.
    let pcmURL: URL
    let duration: TimeInterval
    /// 100 levels in 0…1.
    let waveform: [Float]
}

nonisolated enum VoiceRecorderError: Error, Equatable, Sendable {
    case permissionDenied
    case failed
}

// sourcery: AutoMockable
protocol AudioRecorderBackend: AnyObject {
    var currentTime: TimeInterval { get }
    /// Fires when the system interrupts recording (a call, Siri…) or the recorder ends on its own.
    var interruptions: AnyPublisher<Void, Never> { get }

    func start(url: URL) throws
    func stop()
    /// Refreshes the meters and returns the average power in dBFS.
    func averagePower() -> Float
}

// sourcery: AutoMockable
protocol VoiceMessageRecorderProtocol: AnyObject {
    var statePublisher: AnyPublisher<VoiceRecorderState, Never> { get }
    var state: VoiceRecorderState { get }

    func start() async -> Result<Void, VoiceRecorderError>
    /// Keeps the recording, unless it's shorter than the minimum duration.
    func stop()
    /// Stops if needed, deletes the recording and returns to `.idle`.
    func cancel()
}

final class VoiceMessageRecorder: VoiceMessageRecorderProtocol {
    nonisolated static let waveformCount = 100
    private static let tickInterval = Duration.milliseconds(100)
    private static let silenceLevel: Float = -50

    private let audioSession: AudioSessionProxyProtocol
    private let backend: AudioRecorderBackend
    private let makeTickSleeper: () -> @Sendable (Int) async throws -> Void
    private let haptic: () -> Void
    private let maxDuration: TimeInterval
    private let warningAt: TimeInterval
    private let minimumDuration: TimeInterval

    private let stateSubject = CurrentValueSubject<VoiceRecorderState, Never>(.idle)
    private var recordingURL: URL?
    private var samples: [Float] = []
    /// The last `currentTime` seen, since `AVAudioRecorder` resets it to 0 once it stops.
    private var lastElapsed: TimeInterval = 0
    private var hasWarned = false
    /// Bumped by `cancel`, so a start waiting on the permission prompt knows it was abandoned.
    private var startGeneration = 0
    private var timerTask: Task<Void, Never>?
    private var interruptionsCancellable: AnyCancellable?

    var state: VoiceRecorderState { stateSubject.value }
    var statePublisher: AnyPublisher<VoiceRecorderState, Never> { stateSubject.eraseToAnyPublisher() }

    init(audioSession: AudioSessionProxyProtocol,
         backend: AudioRecorderBackend = AVAudioRecorderBackend(),
         clock: some Clock<Duration> = ContinuousClock(),
         haptic: @escaping () -> Void = { WKInterfaceDevice.current().play(.notification) },
         maxDuration: TimeInterval = 300,
         warningAt: TimeInterval = 270,
         minimumDuration: TimeInterval = 1) {
        self.audioSession = audioSession
        self.backend = backend
        makeTickSleeper = { Self.tickSleeper(on: clock) }
        self.haptic = haptic
        self.maxDuration = maxDuration
        self.warningAt = warningAt
        self.minimumDuration = minimumDuration
    }

    isolated deinit {
        guard isRecording else { return }
        stopRecording()
        removeRecording()
    }

    func start() async -> Result<Void, VoiceRecorderError> {
        guard !isRecording else { return .failure(.failed) }
        startGeneration += 1
        let generation = startGeneration

        guard await audioSession.requestRecordPermission() else { return .failure(.permissionDenied) }
        guard generation == startGeneration, !isRecording else { return .failure(.failed) }

        do {
            try audioSession.activateForRecording()
        } catch {
            MXLog.error("Activating the audio session for recording failed")
            audioSession.deactivate()
            stateSubject.send(.failed)
            return .failure(.failed)
        }

        do {
            let url = try Self.makeRecordingURL()
            recordingURL = url
            try backend.start(url: url)
        } catch {
            MXLog.error("Starting the voice recording failed")
            audioSession.deactivate()
            removeRecording()
            stateSubject.send(.failed)
            return .failure(.failed)
        }

        samples = []
        lastElapsed = 0
        hasWarned = false
        stateSubject.send(.recording(elapsed: 0, level: 0, isNearLimit: false))
        interruptionsCancellable = backend.interruptions.sink { [weak self] in
            MXLog.info("Voice recording interrupted")
            self?.stop()
        }
        startTimer()
        MXLog.info("Voice recording started")
        return .success(())
    }

    func stop() {
        guard isRecording else { return }
        let duration = max(backend.currentTime, lastElapsed)
        stopRecording()

        guard duration >= minimumDuration, let recordingURL else {
            MXLog.info("Voice recording discarded, too short")
            removeRecording()
            stateSubject.send(.discarded)
            return
        }
        self.recordingURL = nil
        MXLog.info("Voice recording stopped after \(duration) s")
        stateSubject.send(.stopped(RecordedVoiceMessage(pcmURL: recordingURL, duration: duration, waveform: Self.waveform(from: samples))))
    }

    func cancel() {
        startGeneration += 1
        if isRecording {
            stopRecording()
            MXLog.info("Voice recording cancelled")
        }
        if case let .stopped(message) = state {
            try? FileManager.default.removeItem(at: message.pcmURL)
        }
        removeRecording()
        stateSubject.send(.idle)
    }

    /// Resamples the level samples to `count` values spanning the whole recording: bucket means when there are
    /// more samples than values, else linear interpolation between neighbouring samples.
    nonisolated static func waveform(from samples: [Float], count: Int = waveformCount) -> [Float] {
        guard samples.count >= count else {
            guard samples.count > 1 else { return Array(repeating: samples.first ?? 0, count: count) }
            return (0..<count).map { index in
                let position = Float(index) * Float(samples.count - 1) / Float(count - 1)
                let lower = min(Int(position), samples.count - 2)
                let fraction = position - Float(lower)
                return samples[lower] + (samples[lower + 1] - samples[lower]) * fraction
            }
        }
        return (0..<count).map { bucket in
            let bucketSamples = samples[bucket * samples.count / count..<(bucket + 1) * samples.count / count]
            return bucketSamples.reduce(0, +) / Float(bucketSamples.count)
        }
    }

    // MARK: - Private

    private var isRecording: Bool {
        if case .recording = state { true } else { false }
    }

    private func startTimer() {
        let sleep = makeTickSleeper()
        timerTask = Task { [weak self] in
            var tick = 1
            while !Task.isCancelled {
                do { try await sleep(tick) } catch { return }
                guard !Task.isCancelled, let self else { return }
                self.tick()
                tick += 1
            }
        }
    }

    private func tick() {
        guard isRecording else { return }
        let elapsed = max(backend.currentTime, lastElapsed)
        lastElapsed = elapsed
        let level = Self.level(fromPower: backend.averagePower())
        samples.append(level)

        if elapsed >= warningAt, !hasWarned {
            hasWarned = true
            MXLog.info("Voice recording nearing its limit")
            haptic()
        }
        stateSubject.send(.recording(elapsed: elapsed, level: level, isNearLimit: hasWarned))

        if elapsed >= maxDuration {
            MXLog.info("Voice recording reached its limit")
            stop()
        }
    }

    /// Releases the microphone and the session; the file stays in `recordingURL`.
    private func stopRecording() {
        timerTask?.cancel()
        timerTask = nil
        interruptionsCancellable = nil
        backend.stop()
        audioSession.deactivate()
    }

    private func removeRecording() {
        guard let recordingURL else { return }
        try? FileManager.default.removeItem(at: recordingURL)
        self.recordingURL = nil
    }

    /// Maps −50…0 dBFS to 0…1.
    private static func level(fromPower power: Float) -> Float {
        guard power.isFinite else { return 0 }
        return (min(max(power, silenceLevel), 0) - silenceLevel) / -silenceLevel
    }

    private static func makeRecordingURL() throws -> URL {
        let directory = VoiceMessageServices.temporaryDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "\(UUID().uuidString).caf")
    }

    /// Sleeps until tick `n` from now, so ticks don't drift when one runs late.
    private static func tickSleeper(on clock: some Clock<Duration>) -> @Sendable (Int) async throws -> Void {
        let start = clock.now
        return { tick in try await clock.sleep(until: start.advanced(by: tickInterval * tick), tolerance: nil) }
    }
}

/// Records 48 kHz mono Float32 PCM to CAF with `AVAudioRecorder`, metering on.
final class AVAudioRecorderBackend: NSObject, AudioRecorderBackend, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private let failures = PassthroughSubject<Void, Never>()

    var currentTime: TimeInterval { recorder?.currentTime ?? 0 }

    var interruptions: AnyPublisher<Void, Never> {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .filter { notification in
                let type = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init)
                return type == .began
            }
            .map { _ in () }
            .merge(with: failures)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func start(url: URL) throws {
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM,
                                       AVSampleRateKey: OpusCodec.sampleRate,
                                       AVNumberOfChannelsKey: 1,
                                       AVLinearPCMBitDepthKey: 32,
                                       AVLinearPCMIsFloatKey: true,
                                       AVLinearPCMIsBigEndianKey: false,
                                       AVLinearPCMIsNonInterleaved: false]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.delegate = self
        guard recorder.record() else { throw AVAudioRecorderBackendError.recordFailed }
        self.recorder = recorder
    }

    func stop() {
        recorder?.stop()
        recorder = nil
    }

    func averagePower() -> Float {
        guard let recorder else { return -.infinity }
        recorder.updateMeters()
        return recorder.averagePower(forChannel: 0)
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard !flag else { return }
        Task { @MainActor in failures.send() }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: (any Error)?) {
        Task { @MainActor in failures.send() }
    }
}

private enum AVAudioRecorderBackendError: Error {
    case recordFailed
}
