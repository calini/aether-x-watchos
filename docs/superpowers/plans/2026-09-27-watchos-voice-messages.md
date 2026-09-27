# Element X watchOS: voice messages, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Record, review and send Ogg Opus voice messages from the watch, and play received ones, using Apple's Opus codec plus a small pure-Swift Ogg writer and reader.

**Architecture:**
- **Encoding and decoding:** `OpusCodec` (`AVAudioConverter`) and `OggOpus` (pure Swift, RFC 3533/7845).
- **Sending:** `VoiceMessageRecorder` (`AVAudioRecorder` to a PCM CAF) → `VoiceMessageEncoder` (CAF → `.ogg`) → `TimelineProxy.sendVoiceMessage`.
- **Receiving:** `VoiceMessagePlayer` downloads, demuxes and decodes to a cached CAF, then plays it with `AVAudioPlayer`.
- **UI:** the screens are MVVM-C, reached from the (+) Attachments sheet and from chat bubbles.

**Tech Stack:** Swift 6.2, SwiftUI, AVFAudio (`AVAudioConverter`, `AVAudioRecorder`, `AVAudioPlayer`, `AVAudioSession`), watchOS 11+ (Liquid Glass on 26), `MatrixRustSDK` (`watchos-http-transport`), Swift Testing, Sourcery, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-09-27-watchos-voice-messages-design.md`. Read it first.

## Global Constraints

- **Repo and branch:** `~/Developer/git/github.com/element-hq/element-x-watchos`, branch `voice-messages` created from `main` (the spec commit `47ccfdd` plus this plan's commit). Don't push. The SDK fork is read-only here. element-x-ios is a read-only reference (`ElementX/Sources/Services/VoiceMessage/`, `ElementX/Sources/Services/Audio/`).
- **Screens:** MVVM-C for every screen, with a `PreviewProvider` covering every main state.
- **Strings:** all go in `WatchStrings`.
- **Styling:** buttons use `.fullWidth` / `.fullWidthProminent` (`ElementXWatch/Sources/Other/SwiftUI/FullWidthButtonStyle.swift`); colours use `Color.compound.*`.
- **Actor isolation:** app target `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Heavy encoding and decoding runs off the main actor (`nonisolated` functions and/or `Task.detached`), using value types or `Sendable` inputs. Never add `@unchecked Sendable` / `nonisolated(unsafe)` by hand.
- **Privacy:** never log audio contents, file paths, media URLs or error strings. Log only events, durations and counts.
- **Licence headers:** new files use the single-line watch header from `FullWidthButtonStyle.swift`. Files derived from element-x-ios keep its header and get a `SHARED_FROM_IOS.md` row.
- **Member order:** properties → init → functions. For views: properties → init → `body` → other views → functions.
- **Mocks:** Sourcery mocks drop the `Protocol` suffix; commit the regenerated `GeneratedMocks.swift`.
- **Tests run on a FRESH throwaway simulator only** (never the user's simulators or Snowflake). Boot and wait first:
  ```bash
  cd ~/Developer/git/github.com/element-hq/element-x-watchos
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/opt/homebrew/bin:$PATH
  RT=$(xcrun simctl list runtimes | grep -o "com.apple.CoreSimulator.SimRuntime.watchOS-26-5"); DT=$(xcrun simctl list devicetypes | grep -o "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-11-46mm" | head -1)
  T=$(xcrun simctl create "EXW Throwaway" "$DT" "$RT"); xcrun simctl bootstatus $T -b; sleep 5
  xcodegen -q && xcodebuild test -project ElementXWatch.xcodeproj -scheme ElementXWatch -destination "platform=watchOS Simulator,id=$T" -parallel-testing-enabled NO 2>&1 | tail -30
  xcrun simctl shutdown $T; xcrun simctl delete $T
  ```
  Output must be pristine: no `warning:` lines from `ElementXWatch/Sources` or `UnitTests/Sources`, no disabled tests.
- **Screenshots of unreachable screens:** use a temporary launch hook and never commit it. Save to `/private/tmp/claude-501/-Users-calini-Developer-git-github-com-element-hq-element-x-ios/25dc6f09-27c4-464d-9da6-1aa543703643/scratchpad/`.
- **Commits:** a title and a description, ending with:
  ```
  Co-Authored-By: <model> <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX
  ```

## Review Focus

1. **Packets ≥ 255 bytes and page boundaries.**
   - Expected: lacing values are 255-runs plus a terminator, and a packet split across pages is reassembled.
   - Pinned in Task 2 (`OggOpusTests.lacingAndMultiPageRoundTrip`).
2. **A 5-minute recording.**
   - Expected: encoding and decoding stay in bounded memory, working in chunks and never loading the whole file.
   - Pinned in Task 1 (`OpusCodecTests.encodesInChunks`, which uses a small injected chunk size and checks several converter calls).
3. **Interruption mid-recording** (a call or Siri).
   - Expected: the recording stops and keeps what was recorded, and the audio session is released.
   - Pinned in Task 4 (`interruptionStopsAndKeeps`).
4. **Two voice messages played one after another.**
   - Expected: the first stops, only one `AVAudioPlayer` exists, and the audio session is released at the end.
   - Pinned in Task 6 (`playingAnotherStopsTheFirst`).
5. **Dismissing the recording sheet at any stage.**
   - Expected: the recorder stops, the temporary files are deleted, and nothing is sent.
   - Pinned in Task 5 (`dismissalDiscards`).

---

### Task 1: `OpusCodec` and the device gate

**Files:**
- Create: `ElementXWatch/Sources/Services/VoiceMessage/OpusCodec.swift`
- Modify: the Settings screen, adding a DEBUG-only "Check audio support" row and its view model action
- Test: `UnitTests/Sources/OpusCodecTests.swift`

**Interfaces produced:**
```swift
enum OpusCodecError: Error, Equatable { case unavailable, encodingFailed, decodingFailed }
struct OpusEncodedAudio: Sendable { let packets: [Data]; let preSkip: UInt16; let frameCount: Int64 /* 48 kHz PCM frames in */ }
enum OpusCodec {
    static let sampleRate = 48_000.0, framesPerPacket: AVAudioFrameCount = 960, bitRate = 24_000
    /// Encodes a PCM file (any format; converted to 48 kHz mono Float32) in chunks of `chunkFrames`.
    nonisolated static func encode(fileAt url: URL, chunkFrames: AVAudioFrameCount = 48_000) throws(OpusCodecError) -> OpusEncodedAudio
    /// Decodes packets to a 48 kHz mono PCM CAF at `outputURL`, dropping `preSkip` frames, in chunks.
    nonisolated static func decode(packets: [Data], preSkip: UInt16, to outputURL: URL) throws(OpusCodecError) -> TimeInterval
    /// Round trip on a generated tone; true when watchOS has both codec directions.
    nonisolated static func selfTest() -> Bool
}
```

The spike code that proved the round trip on the simulator is summarised in spec §2. The encoder uses `AVAudioConverter(from: pcmFloat32 48k mono, to: AudioStreamBasicDescription(kAudioFormatOpus, 48k, 1 ch, framesPerPacket 960))` with `bitRate = 24000`, and reads `AVAudioCompressedBuffer.packetDescriptions`. `preSkip` comes from the converter's `primeInfo.leadingFrames` if it's available; otherwise use 312 (libopus default) and record the choice in the report.

- [ ] **Step 1: Write the failing tests.**
  - `roundTripsATone`: a 1 s 440 Hz tone gives about 50 packets and a decoded length within ±1 packet of 48,000.
  - `encodesInChunks`: a 3 s tone with `chunkFrames: 4800`, with the same guarantee.
  - `selfTestPasses`.
  - `decodeRejectsGarbage`: `[Data([1,2,3])]` gives `.decodingFailed`, or decodes to silence without crashing. Assert whichever the codec does, and document it.
- [ ] **Step 2: Implement.** Write generated tones to a temporary CAF in the tests.
- [ ] **Step 3: Add the Settings row.** Under `#if DEBUG`, a "Check audio support" row runs `OpusCodec.selfTest()` off the main actor and shows "Opus: ✅" or "Opus: ❌".
- [ ] **Step 4: Run the full suite** on a throwaway simulator, then commit: "Add an Opus codec on AVAudioConverter".
- [ ] **Step 5: Device gate. STOP here.** The controller asks the user to run "Check audio support" on Snowflake. Continue only on ✅. On ❌, re-plan with libopus/libogg built from source.

---

### Task 2: `OggOpusWriter` / `OggOpusReader`

**Files:** Create `ElementXWatch/Sources/Services/VoiceMessage/OggOpus.swift`. Test: `UnitTests/Sources/OggOpusTests.swift`.

**Interfaces produced:**
```swift
enum OggOpusError: Error, Equatable { case invalidPage, badChecksum, missingHeaders, notOpus }
struct OggOpusFile: Equatable, Sendable { let preSkip: UInt16; let inputSampleRate: UInt32; let packets: [Data]; let granulePosition: Int64 }
enum OggOpusWriter {
    /// A complete Ogg Opus file. `frameCount` (48 kHz, excluding pre-skip) sets the final granule; ~1 s of packets per page.
    nonisolated static func write(packets: [Data], preSkip: UInt16, frameCount: Int64, serialNumber: UInt32 = .random(in: .min ... .max)) -> Data
}
enum OggOpusReader {
    nonisolated static func read(_ data: Data) throws(OggOpusError) -> OggOpusFile
}
enum OggCRC { nonisolated static func checksum(_ bytes: some Collection<UInt8>) -> UInt32 }   // poly 0x04C11DB7, init 0, no reflection
```

**Format** (RFC 3533 / RFC 7845):
- Page header: `"OggS"`, version 0, header-type flags (0x02 on the first page, 0x04 on the last), granule position (Int64 LE), serial (LE), page sequence (LE), CRC (LE, computed with the CRC field zeroed), segment count, and the lacing table.
- Page 0 holds only `OpusHead`: magic `"OpusHead"`, version 1, channels 1, pre-skip LE16, input rate LE32 = 48000, output gain 0, mapping 0. It has granule 0 and the BOS flag.
- Page 1 holds only `OpusTags`: `"OpusTags"`, vendor length and vendor string "Element X watchOS", and user comment count 0. Granule 0.
- Audio pages carry about 50 packets each (≤ 255 segments). The granule of a page is the cumulative 48 kHz sample count at the end of its last complete packet, including pre-skip. The last page's granule is `preSkip + frameCount`, and it carries EOS. A packet that doesn't fit is continued on the next page (flag 0x01).

- [ ] **Step 1: Write the failing tests.**
  - `crcKnownVector`: compute the CRC of a hand-built minimal page and compare it with a value from an independent calculation in the test comments. Alternatively, validate a known-good Ogg page: include a small real Ogg Opus file's first page bytes as a hex literal (from any public test vector, or generated with `opusenc` if it's available locally) and check its CRC.
  - `roundTripsPackets`: 0, 1 and 120 packets of varied sizes.
  - `lacingAndMultiPageRoundTrip`: packets of 254, 255, 256 and 600 bytes, plus enough packets to span several pages. This is Review Focus #1.
  - `headerFields`: pre-skip, rate and vendor.
  - `eosAndGranule`: the last page has flag 0x04 and granule == preSkip + frameCount.
  - `rejectsCorruptChecksum`.
  - `rejectsNonOpus`.
  - `decodesAnOpusCodecEncodingEndToEnd`: `OpusCodec.encode` → writer → reader → `OpusCodec.decode`.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run the full suite, then commit:** "Add an Ogg Opus writer and reader".

---

### Task 3: sending voice messages (encoder, timeline, proxy, permissions)

**Files:**
- Create: `ElementXWatch/Sources/Services/VoiceMessage/VoiceMessageEncoder.swift`, `ElementXWatch/Sources/Services/VoiceMessage/AudioSessionProxy.swift`
- Modify: `TimelineProxy.swift` (+ protocol), `TimelineItem.swift` / `TimelineItemFactory.swift` (`.voice`), `RoomSummaryPreview.swift` ("🎤 Voice message"), `WatchStrings.swift`, `project.yml` (`NSMicrophoneUsageDescription` = "Record voice messages in chats."), the regenerated Info.plist, `MessageBubble.swift` (a temporary label until Task 6)
- Test: `UnitTests/Sources/VoiceMessageEncoderTests.swift`, `UnitTests/Sources/TimelineItemFactoryVoiceTests.swift`

**Interfaces produced:**
```swift
struct EncodedVoiceMessage: Equatable, Sendable { let fileURL: URL; let duration: TimeInterval; let size: UInt64 }
enum VoiceMessageEncoder {
    /// PCM CAF → .ogg next to it; off the main actor.
    nonisolated static func encode(recordingAt url: URL) throws(OpusCodecError) -> EncodedVoiceMessage
}
struct VoiceBody: Equatable { let duration: TimeInterval; let waveform: [Float]; let source: MediaSourceProxy }   // TimelineItemBody.voice(VoiceBody)
// TimelineProxyProtocol:
func sendVoiceMessage(fileURL: URL, duration: TimeInterval, waveform: [Float]) async -> Result<Void, TimelineProxyError>
// sourcery: AutoMockable
protocol AudioSessionProxyProtocol: AnyObject {
    var recordPermission: MicrophonePermission { get }            // .undetermined/.denied/.granted
    func requestRecordPermission() async -> Bool
    func activateForRecording() throws
    func activateForPlayback() throws
    func deactivate()
}
```

- **Timeline mapping:** an SDK audio message with `voice != nil` becomes `.voice`. Its duration comes from `audio?.duration ?? info?.duration ?? 0`. Its waveform comes from `audio?.waveform`, normalised from 0…1024 to 0…1 as iOS does (check `element-x-ios` for the scale). Other audio stays `.unsupported`.
- **`sendVoiceMessage`:**
  - `UploadParameters(source: .file(filename: fileURL.path(percentEncoded: false)), caption: nil, formattedCaption: nil, mentions: nil, inReplyTo: nil, extraContentJson: nil)`, matching the generated init labels;
  - `AudioInfo(duration: duration, size: size, mimetype: "audio/ogg")`;
  - `try timeline.sendVoiceMessage(...)`, then `try await handle.join()`.
  - Log failures by type only.
- **`AudioSessionProxy`:**
  - `AVAudioApplication.shared.recordPermission` / `requestRecordPermission()`;
  - recording uses `setCategory(.playAndRecord, mode: .default)`;
  - playback uses `setCategory(.playback, mode: .default, policy: .default)`;
  - deactivating uses `setActive(false, options: .notifyOthersOnDeactivation)`.
  - Check the watchOS availability of each call.

- [ ] **Step 1: Write the failing tests.**
  - The encoder: tone CAF → `.ogg` that `OggOpusReader` reads back, with duration ≈ the tone length and a size matching the file.
  - The factory: voice → `.voice` with a normalised waveform; plain audio → unsupported; a missing waveform → empty.
  - The room summary preview string.
- [ ] **Step 2: Implement.** Then `plutil -p` the built Info.plist to show the microphone key.
- [ ] **Step 3: Run the full suite, then commit:** "Send voice messages as Ogg Opus".

---

### Task 4: `VoiceMessageRecorder`

**Files:** Create `ElementXWatch/Sources/Services/VoiceMessage/VoiceMessageRecorder.swift`. Test: `UnitTests/Sources/VoiceMessageRecorderTests.swift`.

**Interfaces produced:**
```swift
enum VoiceRecorderState: Equatable {
    case idle
    case recording(elapsed: TimeInterval, level: Float /* 0…1 */, isNearLimit: Bool)
    case stopped(RecordedVoiceMessage)
    case discarded                  // < 1 s
    case failed
}
struct RecordedVoiceMessage: Equatable, Sendable { let pcmURL: URL; let duration: TimeInterval; let waveform: [Float] /* 100 values 0…1 */ }
// sourcery: AutoMockable
protocol AudioRecorderBackend: AnyObject {           // wraps AVAudioRecorder, for tests
    func start(url: URL) throws
    func stop()
    var currentTime: TimeInterval { get }
    func averagePower() -> Float                     // dBFS, after updateMeters()
    var interruptions: AnyPublisher<Void, Never> { get }
}
// sourcery: AutoMockable
protocol VoiceMessageRecorderProtocol: AnyObject {
    var statePublisher: AnyPublisher<VoiceRecorderState, Never> { get }
    var state: VoiceRecorderState { get }
    func start() async -> Result<Void, VoiceRecorderError>   // .permissionDenied / .failed
    func stop()
    func cancel()                                             // stop + delete files → .idle
}
final class VoiceMessageRecorder: VoiceMessageRecorderProtocol {
    init(audioSession: AudioSessionProxyProtocol, backend: AudioRecorderBackend = AVAudioRecorderBackend(),
         clock: some Clock<Duration> = ContinuousClock(), haptic: @escaping () -> Void = { WKInterfaceDevice.current().play(.notification) },
         maxDuration: TimeInterval = 300, warningAt: TimeInterval = 270, minimumDuration: TimeInterval = 1)
}
```

**Behaviour:**
- **Recording format:** 48 kHz mono Linear PCM Float32 CAF in `FileManager.temporaryDirectory/VoiceMessages/<uuid>.caf`, with metering on.
- **Every 100 ms** (injected clock):
  - update the meters;
  - level = the dBFS power mapped from −50…0 dB to 0…1;
  - append the level to the waveform samples;
  - publish `.recording`.
- **4:30:** at `warningAt`, play the haptic once and set `isNearLimit`.
- **5:00:** at `maxDuration`, stop.
- **Stop:**
  - under 1 s: delete the file and publish `.discarded`;
  - otherwise: reduce the samples to 100 values (the mean of each bucket, padded with the last value) and publish `.stopped`.
- **Interruption:** behaves like stop (Review Focus #3).
- **Session:** activated for recording on start, deactivated on stop and cancel.
- **Privacy:** never log paths.

- [ ] **Step 1: Write the failing tests** (mock backend, test clock, haptic counter):
  - `publishesElapsedAndLevel`
  - `warnsOnceAt4m30`
  - `stopsAt5Minutes`
  - `shortRecordingsAreDiscarded`
  - `interruptionStopsAndKeeps`
  - `cancelDeletesAndGoesIdle`
  - `deniedPermissionFails`
  - `waveformIsReducedTo100Values`
  - `sessionIsReleasedOnStopAndCancel`
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run the full suite, then commit:** "Add the voice message recorder".

---

### Task 5: `VoiceRecordingScreen` and the Attachments row

**Files:**
- Create: `ElementXWatch/Sources/Screens/VoiceRecordingScreen/…` (the MVVM-C set plus `View/VoiceRecordingScreen.swift` and a small `WaveformView` in `ElementXWatch/Sources/Other/SwiftUI/`)
- Modify: `AttachmentsScreen*` (adds a `.voiceMessage` action and a 🎤 row), `ChatScreenCoordinator` (wiring: recorder factory, `TimelineProxy`, `AudioSessionProxy`), `WatchStrings.swift`
- Test: `UnitTests/Sources/VoiceRecordingScreenViewModelTests.swift`, additions to `AttachmentsScreenViewModelTests.swift`

**Interfaces produced:**
```swift
enum VoiceRecordingStep: Equatable { case permissionDenied, recording(elapsed: TimeInterval, level: Float, isNearLimit: Bool),
                                     preparing, review(EncodedVoiceMessage, waveform: [Float]), sending }
struct VoiceRecordingScreenViewState: BindableState { var step: VoiceRecordingStep; var isPlaying: Bool; var playbackProgress: Double; var bindings: VoiceRecordingScreenBindings }
struct VoiceRecordingScreenBindings { var errorMessage: String?; var canRetrySend: Bool }
enum VoiceRecordingScreenViewAction { case appear, stop, togglePlayback, send, retrySend, delete, dismiss }
enum VoiceRecordingScreenViewModelAction { case done }
// VoiceRecordingScreenViewModel(recorder:, encode: (URL) async -> Result<EncodedVoiceMessage, OpusCodecError>,
//     send: (EncodedVoiceMessage, [Float]) async -> Result<Void, TimelineProxyError>, previewPlayer: VoiceMessagePreviewPlayerProtocol)
```

**Flow** (spec §4):
- `appear` starts the recorder: a permission failure goes to `.permissionDenied`, success to `.recording`.
- `stop` (or the recorder's own stop) → `.preparing` → encode off the main actor → `.review`.
- If the recording is `.discarded`, emit `.done`.
- If encoding fails, show "Couldn't prepare voice message." and then `.done`.
- `togglePlayback` plays the encoded `.ogg` through a small `VoiceMessagePreviewPlayer`. That player decodes the Ogg to a temporary CAF with `OggOpusReader` + `OpusCodec` and plays it with `AVAudioPlayer`. Keep it simple; Task 6's player reuses the same decode path.
- `send` → `.sending`: on success, delete the files and emit `.done`; on failure, show the "Couldn't send voice message." alert with Try again (`retrySend`) and Cancel.
- `delete`, `dismiss` or ✕ cancels the recorder and deletes the files (Review Focus #5).
- **Keep the busy state until `.done`:** don't re-enable Send during the dismiss (the same lesson as the Location sheet).

**UI:**
- **Recording:** a pulsing red dot (Compound `iconCriticalPrimary`), the "m:ss" time (amber `textWarning`-ish Compound token when near the limit), a level meter, and a **Stop** button (`.fullWidthProminent` with a critical tint, or a large round glass stop).
- **Review:** ▶︎/❚❚ glass circle, `WaveformView` with progress, the duration, **Send** (`.fullWidthProminent`) and **Delete** (`.fullWidth`, destructive).
- **Preparing and sending:** a spinner.
- **Permission denied:** the explanation text.

**Strings** (`WatchStrings`): `voiceMessage = "Voice message"`, `microphoneAccessOff = "Microphone access is off. Turn it on in Settings → Privacy & Security → Microphone."`, `preparingVoiceMessage = "Preparing…"`, `prepareVoiceMessageFailed = "Couldn't prepare voice message."`, `sendVoiceMessageFailed = "Couldn't send voice message."`, `send = "Send"`, `delete = "Delete"` (reuse any that already exist).

- [ ] **Step 1: Write the failing tests** for the view model:
  - `appearStartsRecording`
  - `deniedPermissionShowsExplanation`
  - `stopPreparesThenReviews`
  - `shortRecordingFinishes`
  - `encodeFailureShowsErrorAndFinishes`
  - `sendSucceedsAndFinishes`
  - `sendFailureOffersRetry`
  - `deleteDiscards`
  - `dismissalDiscards` (Review Focus #5)
  - `doubleTapSendSendsOnce`
  - `recorderAutoStopReviews`

  Also a test for the Attachments `.voiceMessage` action.
- [ ] **Step 2: Implement.** Add previews for each step.
- [ ] **Step 3: Run the full suite.** Take screenshots through the hook (`voice-recording.png`, `voice-review.png`), then commit: "Add voice message recording and review".

---

### Task 6: `VoiceMessagePlayer`, the bubble, and TESTING.md

**Files:**
- Create: `ElementXWatch/Sources/Services/VoiceMessage/VoiceMessagePlayer.swift`, `ElementXWatch/Sources/Screens/ChatScreen/View/VoiceMessageBubble.swift`
- Modify: `MessageBubble.swift` (replaces the Task 3 label), `ChatScreen*` (play/pause actions; stop on disappear), `AppCoordinator` (one player per session, like `LocationServices`; stopped on sign-out), `TESTING.md`
- Test: `UnitTests/Sources/VoiceMessagePlayerTests.swift`, additions to `ChatScreenViewModelTests.swift`

**Interfaces produced:**
```swift
enum VoicePlaybackState: Equatable { case idle, preparing(id: String), playing(id: String, progress: Double, elapsed: TimeInterval),
                                     paused(id: String, progress: Double, elapsed: TimeInterval), failed(id: String) }
// sourcery: AutoMockable
protocol VoiceMessagePlayerProtocol: AnyObject {
    var statePublisher: AnyPublisher<VoicePlaybackState, Never> { get }
    var state: VoicePlaybackState { get }
    func play(id: String, source: MediaSourceProxy) async
    func pause()
    func stop()
}
// VoiceMessagePlayer(loadContent: (MediaSourceProxy) async -> Data?, audioSession:, cacheDirectory:, cacheLimitBytes: 20_000_000,
//                    makeAudioPlayer: (URL) throws -> AudioPlaybackBackend (AVAudioPlayer wrapper, mockable), clock:)
```

**Behaviour:**
- `play` on a different ID stops the current one first (Review Focus #4).
- Prepare: cache hit, or download → `OggOpusReader` → `OpusCodec.decode` into `Caches/VoiceMessages/<sha256 of media URL>.caf`. Evict least recently used files over 20 MB.
- Prepare errors → `.failed(id)`. Playing a `.failed` ID again retries.
- While playing, publish progress every 0.1 s. At the end → `.idle`.
- The session is `activateForPlayback()` while playing and `deactivate()` when stopped, idle or ended.
- **Chat:** `ChatScreenViewModel` exposes the playback state per voice item; the view model stops the player when the chat disappears.
- **Bubble:**
  - ▶︎/❚❚/spinner/⚠︎ circle;
  - `WaveformView` with progress (30 placeholder bars when there's no waveform);
  - the time: total when idle, elapsed when playing or paused;
  - accessibility label "Voice message, 0:12"; the button toggles playback.
- **TESTING.md:** add the manual rows from spec §7.

- [ ] **Step 1: Write the failing tests** (mock backend, a stub `loadContent` returning a real `.ogg` built with `OggOpusWriter` from an encoded tone, and a test clock):
  - `preparesAndPlays`
  - `usesTheCacheSecondTime`
  - `playingAnotherStopsTheFirst`
  - `pauseAndResume`
  - `endReturnsToIdleAndReleasesSession`
  - `downloadFailureFails`
  - `corruptFileFails`
  - `failedRetriesOnPlay`
  - `cacheEvictsOverLimit`

  Also chat VM tests for the actions and stopping on disappear.
- [ ] **Step 2: Implement,** with previews for the bubble: idle, preparing, playing, paused, failed and no-waveform.
- [ ] **Step 3: Run the full suite.** Take a screenshot of a chat with voice bubbles (`voice-bubbles.png`), then commit: "Play voice messages in chats".
