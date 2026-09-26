# Sub-project 1 testing session

## How to install

1. Build the SDK for devices with the full `Tools/build-sdk.sh` (not `--dev`, which is simulator only; ~12 minutes), then run `xcodegen`.
2. Open `ElementXWatch.xcodeproj` in Xcode.
3. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set `DEVELOPMENT_TEAM`. Find your Team ID in the Apple Development certificate: `security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject` and use the `OU=` value (Xcode doesn't show it for Personal Teams). The value in parentheses in the certificate's `CN=` is **not** the Team ID.
4. Keep the scheme's Run action on the **Debug** configuration: the transport audit's tripwire proxy (`127.0.0.1:9`) only exists in Debug builds.
5. Select the watch as the run destination and Run. On a real watch, build from commit `c680eec` (runpath fix) or later.
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

## Transport audit

- [ ] Console (Xcode → Devices → Open Console, filter `io.ilie.elementx.watch`) shows no `127.0.0.1:9` / proxy connection errors during the session.
- [ ] Rust logs downloaded from the app container (`Library/Caches/Logs/rust*.log`) show no reqwest connection attempts.

## Known issues

- Network errors inside the transport currently surface as an SDK panic (`HttpTransportError` is a flat uniffi error). If sync stops after a network change (phone off, Wi-Fi/LTE switch, wrist down/up), note it — fix pending in the SDK fork.

## Issues found

-
