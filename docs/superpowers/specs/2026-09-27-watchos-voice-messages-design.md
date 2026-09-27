# Element X watchOS: voice messages

Date: 2026-09-27
Status: design approved in conversation
Builds on: location sharing (`705b98e`), which added the (+) Attachments sheet

## 1. Why

The user wants to record and send voice messages from the watch without the phone, and to play the voice messages they receive, in DMs and groups. Messages must play normally in Element X on other devices.

## 2. Findings that shape the design

- **Format:** Element X iOS records AAC and converts it to Ogg Opus before sending (`audio/ogg`, via element-hq's `SwiftOGG`). Its voice message player only accepts `audio/ogg`. So the watch must send Ogg Opus.
- **`SwiftOGG` on the watch:** it depends on prebuilt `YbridOpus` and `YbridOgg` binaries (vector-im/opus-swift and ogg-swift) that exist only for iOS and macOS.
- **Opus on watchOS:** the watchOS SDK defines `kAudioFormatOpus`. A spike on the watchOS 26.5 simulator encoded one second of a 440 Hz tone to Opus with `AVAudioConverter` (51 packets, about 3.9 KB, 24 kbps) and decoded it back to exactly 48,000 frames. So Apple's codec can produce and read Opus, and only the Ogg container is missing. **The real device still has to be confirmed** (plan Task 1), because the simulator may use the Mac's codecs.
- **Recording and playback APIs:** `AVAudioRecorder`, `AVAudioPlayer` and the `playAndRecord` / `record` audio session categories are all available on watchOS.
- **The SDK already has what's needed:**
  - `Timeline.sendVoiceMessage(params: UploadParameters, audioInfo: AudioInfo, waveform: [Float]) -> SendAttachmentJoinHandle`, where `UploadParameters.source` is `.file(filename:)` and `AudioInfo` has `duration`, `size` and `mimetype`.
  - Received voice messages arrive as `MessageType.audio(AudioMessageContent)`, with `voice != nil` and `audio: UnstableAudioDetailsContent { duration, waveform: [UInt16] }`.
  - The media download already exists (`MediaLoader.loadContent`).
- **What the watch has today:** received audio shows as an unsupported message.

## 3. Scope

In scope:
1. A 🎤 **Voice message** row in the Attachments sheet.
2. Recording:
   - it starts at once;
   - the screen shows a pulsing red dot, the elapsed time, a live level meter, **Stop**, and the system ✕ to cancel;
   - the watch vibrates at 4:30, and recording stops automatically at 5:00.
3. A review screen with **▶︎ / ❚❚**, a waveform and the duration, **Send** (prominent glass) and **Delete**.
4. Sending as Ogg Opus (`audio/ogg`), with a waveform and duration, marked as a voice message.
5. Received voice message bubbles, and your own sent ones:
   - **▶︎ / ❚❚**, a waveform, and the time (total when stopped, counting while playing);
   - one message plays at a time, and playback stops when you leave the chat;
   - audio goes through the watch speaker, or AirPods if connected.
6. Microphone permission, audio session handling, and interruptions (calls, Siri).

Out of scope:
- a playback speed control;
- scrubbing within a message;
- recording in the background;
- the C-library fallback (only needed if Task 1 fails on the device);
- sending other audio files.

## 4. Screens and flows

**Sending**
- **(+) → Voice message** pushes the Recording screen and starts recording.
- **First use:** the system asks for microphone permission. If denied, the screen says "Microphone access is off. Turn it on in Settings → Privacy & Security → Microphone." and nothing is recorded.
- **Recording screen:**
  - a red dot pulsing with the input level, the elapsed time "m:ss", and a small live level meter;
  - a large **Stop** button;
  - the system ✕ cancels, discarding the recording.
  - At 4:30 the watch plays a haptic (`WKInterfaceDevice.current().play(.notification)`) and the time turns amber. At 5:00 recording stops as if you'd tapped Stop.
- **Stop** leads to encoding, which shows "Preparing…", then the **Review screen**:
  - ▶︎ / ❚❚ plays the encoded file;
  - the waveform shows progress;
  - the duration counts down while playing;
  - **Send** (prominent glass) and **Delete** (plain glass, destructive tint).
- **Sending:** Send shows a spinner. On success the Attachments sheet closes. On failure the alert "Couldn't send voice message." offers Try again and Cancel; the file is kept until you send or delete it.
- **Delete, ✕ and dismissal:** Delete, ✕, or dismissing the sheet removes the temporary files.

**Receiving (voice message bubbles)**
- **Layout:** a ▶︎ circle button, the waveform (from `audio.waveform`, else 30 equal placeholder bars), and the time.
- **Tapping ▶︎:**
  - if the message isn't prepared yet, the button shows a spinner while it downloads, demuxes and decodes;
  - it then plays, the waveform fills with progress, and the time counts up;
  - ❚❚ pauses;
  - playing another message stops the first.
- **Failures:** if downloading or decoding fails, the button shows ⚠︎, and tapping it tries again.
- **Leaving the chat** stops playback.

## 5. Components

| Unit | Responsibility |
|---|---|
| `OggOpusWriter` / `OggOpusReader` (`Services/VoiceMessage/OggOpus.swift`) | Pure Swift, RFC 3533 + RFC 7845. The writer produces the OpusHead page (version 1, 1 channel, pre-skip from the encoder, 48 kHz input rate, mapping family 0), the OpusTags page (vendor "Element X watchOS"), then audio pages. Pages hold about 1 s of packets. Lacing handles packets of 255 bytes or more. Granule positions are cumulative 48 kHz samples. The Ogg CRC-32 uses polynomial 0x04C11DB7, with no reflection and an initial value of 0. The last page is flagged end-of-stream, and its granule is trimmed to the real length. The reader parses pages, validates CRCs, reassembles packets across pages, and returns the header fields (pre-skip) and audio packets. |
| `OpusCodec` (`Services/VoiceMessage/OpusCodec.swift`) | `AVAudioConverter` between 48 kHz mono Float32 PCM and Opus (20 ms, 960-frame packets, 24 kbps). It encodes from an `AVAudioFile` in chunks, so memory stays bounded, and yields packets and the total frames. It decodes packets to PCM in chunks, writing into an `AVAudioFile` (CAF, PCM). It drops pre-skip samples when decoding. |
| `VoiceMessageRecorderProtocol` / `VoiceMessageRecorder` | Wraps `AVAudioRecorder`, recording 48 kHz mono Linear PCM CAF to a temp file with metering on. It publishes the state `.idle / .recording(elapsed, level) / .stopped(url, duration, waveform) / .failed`. It samples the level every 100 ms for the meter and the waveform, and reduces the waveform to 100 values in 0…1. It handles the 4:30 warning, the 5:00 limit, the 1 s minimum (shorter recordings are discarded), and interruptions (stop and keep). Timers use an injectable clock, and the recorder backend sits behind a protocol for tests. |
| `VoiceMessageEncoder` | Turns a PCM CAF into an `.ogg` file (`OpusCodec` plus `OggOpusWriter`), off the main actor, and returns the file, duration and size. |
| `VoiceMessagePlayerProtocol` / `VoiceMessagePlayer` | One per session. `play(item:)`, `pause()`, `stop()`. It publishes `.idle / .preparing(id) / .playing(id, progress, elapsed) / .paused(id, …) / .failed(id)`. It prepares by downloading through `MediaLoader.loadContent` (or reading a local file), then `OggOpusReader` and `OpusCodec` decode into a cached CAF under Caches/VoiceMessages, keyed by the media source URL. The cache is capped at 20 MB, least recently used first, and cleared on sign-out, since it holds decrypted audio. It plays with `AVAudioPlayer`, sets the audio session to `.playback` while playing and deactivates it afterwards. |
| `AudioSessionProxy` | Sets the category and activates or deactivates the session, for recording (`.playAndRecord`, `.default`) and playback (`.playback`). Behind a protocol for tests. |
| Timeline | `TimelineItemBody.voice(VoiceBody { duration, waveform: [Float] (0…1), source: MediaSourceProxy })`, mapped from audio with `voice != nil`. Other audio stays unsupported. |
| `TimelineProxy.sendVoiceMessage(fileURL:duration:waveform:)` | Reads the file and builds `UploadParameters(source: .data(bytes:, filename: "voice-message.ogg"), …)` (the name Element X iOS uses, which becomes the event body) and `AudioInfo(duration:, size:, mimetype: "audio/ogg")`, calls `timeline.sendVoiceMessage(...)`, and awaits `join()`. Returns `Result<Void, TimelineProxyError>`. |
| Screens | `VoiceRecordingScreen` (MVVM-C: recording, preparing, review, sending and error states); the `AttachmentsScreen` row; `VoiceMessageBubble` in `MessageBubble`. |
| Config | `NSMicrophoneUsageDescription` = "Record voice messages in chats." |

## 6. Errors

| Situation | What happens |
|---|---|
| Microphone permission denied | The explanation text; nothing recorded |
| Recording interrupted | Recording stops and moves to Preparing and Review with what was recorded |
| Recording under 1 s | Discarded silently; back to the Attachments sheet |
| Encoding fails | Alert "Couldn't prepare voice message." Back to the Attachments sheet |
| Sending fails | Alert "Couldn't send voice message." with Try again and Cancel; the file is kept. This covers failures to hand the message to the send queue; once queued, a network failure shows as a failed local echo in the chat, retried like any other message |
| Download or decoding fails | The bubble shows ⚠︎; tap to retry. Files over 5 MB are refused, and decoding stops at 15 minutes (Element Web's limit), so a hostile file can't fill the disk |
| Playback interrupted (a call, Siri, the app suspending) | Playback pauses and releases the audio session; ▶︎ resumes it |

**Privacy:** audio contents and file paths are never logged, only events, durations and counts.

## 7. Testing

- **Task 1 (device gate):** a DEBUG-only "Check audio support" row in Settings runs an Opus encode/decode round trip and shows ✅ or ❌. The user runs it on Snowflake. On ❌, stop and re-plan with the C-library fallback.
- **Unit tests (Swift Testing):**
  - `OggOpus`: a CRC-32 known vector; writer → reader round trips (0, 1 and many packets, packets of 255 and 510+ bytes, several pages); header fields; the EOS flag and granule trimming; rejecting a corrupted CRC.
  - `OpusCodec` round trips on generated tones: packet count, and decoded length ≈ input length.
  - `VoiceMessageRecorder`, with a mock backend and a test clock: the warning at 4:30, the stop at 5:00, the 1 s minimum, interruption stops and keeps, waveform reduction to 100 values.
  - The `VoiceRecordingScreen` view model: every state and error.
  - `VoiceMessagePlayer`: one message at a time, prepare errors lead to failed, the cache limit.
  - Timeline mapping.
- **Previews and screenshots** of the recording, review and bubble states.
- **Manual on the watch** (in `TESTING.md`):
  - send a voice message and check it plays in Element X on the iPhone;
  - check a voice message from the iPhone plays on the watch, through the speaker and through AirPods;
  - check the 4:30 warning and the 5:00 automatic stop;
  - interrupt a recording with a call;
  - deny microphone permission.
