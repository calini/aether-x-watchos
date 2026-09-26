# Sub-project 1 testing session

## How to install

1. Build the SDK for devices with the full `Tools/build-sdk.sh` (not `--dev`, which is simulator only; ~12 minutes), then run `xcodegen`.
2. Open `ElementXWatch.xcodeproj` in Xcode.
3. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set `DEVELOPMENT_TEAM` (Xcode → Settings → Accounts → your Apple ID → Team ID).
4. Keep the scheme's Run action on the **Debug** configuration: the transport audit's tripwire proxy (`127.0.0.1:9`) only exists in Debug builds.
5. Select the watch as the run destination and Run.
6. On the iPhone, in Element X: tap the version number in Settings 7 times, then turn on **Developer options → Link new device**.

Date: 2026-09-26 · Watch: Apple Watch Series 9 (arm64), watchOS __ · SDK fork: `744352d11` · App: `28c590b`

## Measurements

| Item | Value |
|---|---|
| Release .app size | 282M |
| arm64 __TEXT | 76,857,344 bytes (~73.3 MB) |
| arm64_32 __TEXT (built, not run) | 74,874,880 bytes (~71.4 MB) |
| Minimum OS per slice | arm64: watchOS 26.0 · arm64_32: watchOS 11.0 (both `LC_BUILD_VERSION`, `xcrun vtool -show-build`) |
| Peak memory on the chats list (Xcode memory gauge) | |
| Peak memory in a busy group chat | |

## Checklist (spec §7)

| # | Check | Result | Notes |
|---|---|---|---|
| 1 | iPhone in airplane mode (briefly online to scan/approve), watch on Wi-Fi/LTE: QR login succeeds; Settings shows "Verified session" | | |
| 2 | Chats list shows DMs + groups with previews and unread dots; no spaces | | |
| 3 | Encrypted DM history decrypts; scrolling up loads older messages | | |
| 4 | Dictated reply sent with the phone off arrives on another client | | |
| 5 | Reaction and reply-to-message work | | |
| 6 | Wrist down, receive messages, wrist up: caught up within seconds | | |
| 7 | Sign out clears the session and returns to QR login | | |
| 8 | Release build including arm64_32 succeeds | | |
| 9 | Open a chat, go back, open it again quickly: no duplicate timeline or stuck loading (stray chat coordinator check) | | |

## Transport audit

- [ ] Console (Xcode → Devices → Open Console, filter `io.ilie.elementx.watch`) shows no `127.0.0.1:9` / proxy connection errors during the session.
- [ ] Rust logs downloaded from the app container (`Library/Caches/Logs/rust*.log`) show no reqwest connection attempts.

## Issues found

-
