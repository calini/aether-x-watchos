# Sub-project 1 testing session

## How to install

1. Check out https://github.com/calini/matrix-rust-sdk at `../matrix-rust-sdk` (or set `MATRIX_RUST_SDK_PATH`): `watchos-http-transport` (recommended) for arm64 watches such as the Series 9, or `watchos-http-transport-arm64_32` to also support arm64_32 watches (SE 2nd generation, Series 6–8). Build the SDK for devices with the full `Tools/build-sdk.sh` (not `--dev`, which is simulator only; ~12 minutes), then run `xcodegen`.
2. Open `AetherXWatch.xcodeproj` in Xcode.
3. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set `DEVELOPMENT_TEAM`. Find your Team ID in the Apple Development certificate: `security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject` and use the `OU=` value (Xcode doesn't show it for Personal Teams). The value in parentheses in the certificate's `CN=` is **not** the Team ID.
4. Keep the scheme's Run action on the **Debug** configuration: the transport audit's tripwire proxy (`127.0.0.1:9`) only exists in Debug builds.
5. Select the watch as the run destination and Run. On a real watch, build from commit `c680eec` (runpath fix) or later.
6. On the iPhone, in Element X: tap the version number in Settings 7 times, then turn on **Developer options → Link new device**.

Date: 2026-09-26 · Watch: Apple Watch Series 9 (arm64), watchOS __ · SDK fork: `watchos-http-transport-arm64_32` @ `229ede199` · App: `28c590b`

## Measurements

| Item | Value |
|---|---|
| Release .app size | 281M |
| arm64 __TEXT | 76,939,264 bytes (~73.4 MB) |
| arm64_32 __TEXT (built, not run) | 74,170,368 bytes (~70.7 MB) |
| Minimum OS per slice | arm64: watchOS 26.0 · arm64_32: watchOS 11.0 (both `LC_BUILD_VERSION`, `xcrun vtool -show-build`) |
| Peak memory on the chats list (Xcode memory gauge) | |
| Peak memory in a busy group chat | |

## Checklist (spec §7)

| # | Check | Result | Notes |
|---|---|---|---|
| 1 | Server screen shows `matrix.org`; Continue shows **Sign in with password** only (matrix.org has no QR sign-in). | | |
| 2 | Password sign-in works; a wrong password shows 'Wrong username or password.' and keeps the username. | | |
| 3 | Verify: Start, then accept on the iPhone. The 7 emojis match on both devices, They match gives Verified, and older encrypted DM history decrypts. Also: Not now opens chats, and Settings shows *Verify this watch* until verified. | | |
| 4 | Chats list shows DMs + groups with previews and unread dots; no spaces | | |
| 5 | Encrypted DM history decrypts; scrolling up loads older messages | | |
| 6 | Dictated reply sent with the phone off arrives on another client | | |
| 7 | Reaction and reply-to-message work | | |
| 8 | Wrist down, receive messages, wrist up: caught up within seconds | | |
| 9 | Sign out clears the session and returns to the server screen | | |
| 10 | Release build including arm64_32 succeeds | | |
| 11 | Open a chat, go back, open it again quickly: no duplicate timeline or stuck loading (stray chat coordinator check) | | |
| 12 | *(Optional — N/A if no QR server is available.)* A server that supports QR sign-in still offers and completes QR sign-in on the chosen server. Also: start QR, go back, choose Password — password sign-in works. | | |

## Location sharing (spec §8)

Location permission: the first share asks for "when in use" access; a live share also needs background location, which keeps updates flowing with the wrist down. If access was declined, turn it on in Settings → Privacy & Security → Location Services.

| # | Check | Result | Notes |
|---|---|---|---|
| L1 | (+) → Location → **Send current location**: the location shows in Element X on the iPhone. | | |
| L2 | **Share live · 15 min**, then walk around with the wrist down: updates arrive on the iPhone. The chat shows the pill "📍 Sharing live · N min left", counting down every minute. | | |
| L3 | Tap **Stop** (on the pill, or on your own live bubble): the share ends everywhere and the pill disappears. | | |
| L4 | Start a live share on the iPhone: the watch shows it, and the full-screen map follows it. | | |
| L5 | A share whose sender never stops it (e.g. phone switched off) reads "Live location ended" once its time runs out, in the bubble and on the full-screen map. | | |
| L6 | Battery use over a 1-hour share (note start and end %). | | |

## Voice messages (spec §7)

Microphone permission: the first recording asks for it. If it was declined, turn it on in Settings → Privacy & Security → Microphone.

| # | Check | Result | Notes |
|---|---|---|---|
| V1 | (+) → Voice message, record a few seconds, Stop, review (▶︎ plays it, the waveform spans the whole width), then Send: it plays in Element X on the iPhone. | | |
| V2 | A voice message sent from the iPhone plays on the watch: the button spins while it loads, the waveform fills and the time counts up. Check it through the watch speaker and through AirPods. | | |
| V3 | Record past 4:30: the watch taps your wrist and the time turns amber. At 5:00 recording stops by itself and goes to review. Watch for the tap in particular: recording mutes haptics unless the app allows them, which it now does. | | |
| V4 | Interrupt a recording with a phone call: it stops and keeps what was recorded. | | |
| V5 | Deny microphone permission: the recording screen explains how to turn it on, and nothing is recorded. | | |
| V6 | Play one voice message, then another: the first stops. Leave the chat while one plays: playback stops. Open (+) while one plays: playback stops. | | |
| V7 | With no connection, play a voice message that was never played: the button shows ⚠︎. Reconnect and tap it: it plays. | | |
| V8 | Lower your wrist while recording, and again while a message plays: note what happens to each (recording keeps going or stops and keeps; playback pauses and ▶︎ resumes it). Repeat both with a live location share running. | | |
| V9 | Ask Siri something, and take a call, while a message plays in a chat and while the review screen plays: playback pauses, ❚❚ turns back to ▶︎, and ▶︎ resumes it. | | |
| V10 | Voice messages sent from Element Web and Element X Android play on the watch, and the watch's play in both. | | |
| V11 | A 5-minute voice message from another device: note how long the spinner runs before it plays (the decode time). | | |
| V12 | Battery over ~10 minutes of voice message playback (note start and end %). | | |
| V13 | With AirPods connected, a message plays through them; disconnect them mid-message and note what happens. | | |
| V14 | Tap ✕ while recording: the sheet closes and nothing is sent (and no recording is left playing or recording). | | |
| V15 | Long-press a playing voice message: note whether playback stops when the actions open. | | |

## Transport audit

- [ ] Console (Xcode → Devices → Open Console, filter `io.ilie.aetherx.watch`) shows no `127.0.0.1:9` / proxy connection errors during the session.
- [ ] Rust logs downloaded from the app container (`Library/Caches/Logs/rust*.log`) show no reqwest connection attempts.

## Known issues

- Fixed: network errors inside the transport used to surface as an SDK panic (`rustPanic("Can't lift flat errors")`), because `HttpTransportError` was a flat uniffi error. They are now ordinary network errors that the SDK retries. If sync still stops after a network change (phone off, Wi-Fi/LTE switch, wrist down/up), note it under Issues found.

## Issues found

-
