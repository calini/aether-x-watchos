# Element X watchOS — Design (Sub-project 1: SDK transport, QR login, chats)

Date: 2026-09-25
Status: Approved design, pending written-spec review

## 1. Intent

A standalone watchOS Matrix client derived from Element X iOS, used to read and reply to direct chats and groups from an Apple Watch **without the paired iPhone being reachable**.

- **Audience:** personal use (own bundle IDs, sideloaded via Xcode on a free Apple ID). If successful, it may be offered to the Element team, so SDK changes must be upstreamable.
- **Account:** matrix.org (OAuth/MAS login, Simplified Sliding Sync).
- **Success for this sub-project:** the watch signs in via QR code from Element X iOS, shows DMs and groups, decrypts history, and sends replies/reactions with the phone offline.

### Roadmap (each item gets its own spec → plan → implementation cycle)

1. **SDK transport + QR login + chats** ← this spec
2. Testing session on a real Apple Watch Series 9
3. Push notifications (needs paid Apple Developer account + self-hosted push gateway)
4. Starting new DMs
5. Audio calls (starts with its own feasibility spike — see §10)
6. iPhone ↔ watch sync (WatchConnectivity)

Spaces are out of scope for the whole roadmap for now.

## 2. Key constraint and chosen architecture

watchOS forbids low-level networking (BSD sockets, Network framework, `URLSessionWebSocketTask`, `URLSessionStreamTask`) outside audio-streaming/CallKit contexts (Apple TN3135). Only `URLSession` data tasks are permitted. The matrix-rust-sdk's HTTP stack (reqwest/hyper) opens its own sockets.

**Decision:** run the full matrix-rust-sdk (`matrix-sdk-ffi`, same as Element X iOS) on the watch, and add a **pluggable `HttpTransport`** so all SDK HTTP traffic is executed by a Swift `URLSession` implementation. reqwest remains the default, so iOS behaviour is unchanged.

### Spike evidence (2026-09-25, throwaway code)

- `matrix-sdk-ffi` compiles unmodified for `aarch64-apple-watchos` and `aarch64-apple-watchos-sim` (nightly + `-Zbuild-std`; the SDK's `xtask` already lists watchOS as tier-3 targets).
- `arm64_32-apple-watchos` compiles with two fixes: `AWS_LC_SYS_NO_ASM=1` (requires `cmake`) and a `constant_time_eq` cfg fix (NEON path assumed 64-bit words).
- A ~150-line prototype transport (9 files) ran server discovery + login-details against matrix.org in the watchOS simulator: all 6 requests went through `URLSession`, with the SDK's reqwest proxy set to a dead port (`127.0.0.1:9`) as a bypass tripwire. The SQLite store worked on-watch.
- Generated Swift bindings require **Swift 5 language mode** (as in `matrix-rust-components-swift`).

## 3. Repositories and build pipeline

```
github.com/element-hq/
├── element-x-ios/        unchanged; read-only reference
├── element-x-watchos/    new repo (this one)
└── matrix-rust-sdk/      user's fork, branch `watchos-http-transport`
```

### 3.1 matrix-rust-sdk fork

Base commit: `85bad975d462be6578964991905e8e9bf8314a6f` (the SDK commit behind components `26.09.22`, which element-x-ios `ad1d7a301` pins). Changes as small, individually upstreamable commits:

1. **`HttpTransport` trait** in `crates/matrix-sdk/src/http_client/transport.rs`:
   `fn execute(&self, request: http::Request<Bytes>, timeout: Option<Duration>) -> BoxFuture<'static, Result<http::Response<Bytes>, TransportError>>`.
   `HttpClient` holds `Option<Arc<dyn HttpTransport>>`; when set it replaces the reqwest call in `native.rs`. `HttpError::Transport` maps to `RetryKind::NetworkFailure`. `ClientBuilder::http_transport(...)`.
2. **Route the remaining reqwest bypasses through the transport:**
   - OAuth (`authentication/oauth/http_client.rs`, `oauth/mod.rs` via `oauth2-reqwest`),
   - QR login rendezvous/secure channel (`qrcode/rendezvous_channel/msc_4108.rs`, `qrcode/secure_channel/mod.rs`, `qrcode/grant.rs`, `qrcode/login.rs`),
   - `Client::http_client()` consumers, incl. `bindings/matrix-sdk-ffi/src/client.rs`.
   Test-only `reqwest::Client::new()` sites stay as they are.
3. **FFI:** `HttpTransport` callback interface (`HttpTransportRequest`/`HttpTransportResponse`/`HttpHeader` records, `HttpTransportError.Network`), `ClientBuilder.httpTransport(transport:)`.
4. **arm64_32:** `constant_time_eq` fix via `[patch.crates-io]` (and upstream PR to that crate).

### 3.2 element-x-watchos layout

- `project.yml` (XcodeGen, conventions from element-x-ios): targets `ElementXWatch` (watch-only app, `WKWatchOnly`, deployment target watchOS 11.0) and `UnitTests`.
- `Packages/MatrixRustSDK/` — local Swift package mirroring `matrix-rust-components-swift` (module `MatrixRustSDK`, generated sources compiled in Swift 5 mode). The xcframework is git-ignored and built locally.
- `Packages/CompoundTokens/` — local package exposing the `compound-design-tokens` SwiftUI colour tokens, fonts and icon assets, **excluding** `CompoundCoreUIColorTokens.swift` and `CompoundUIColorTokens.swift` (UIKit-only; the only files that fail on watchOS).
- `Tools/build-sdk.sh` — runs `cargo xtask swift build-framework` in `../matrix-rust-sdk` for `aarch64-apple-watchos`, `arm64_32-apple-watchos`, `aarch64-apple-watchos-sim`, with `AWS_LC_SYS_NO_ASM=1`, **without** the `sentry` feature (Sentry opens its own sockets), `--watchos-deployment-target 11.0`; copies outputs into `Packages/MatrixRustSDK`. `--dev` builds only the simulator slice.
- `SHARED_FROM_IOS.md` — provenance ledger (see §4).
- `AGENTS.md` + `CLAUDE.md` — conventions adapted from element-x-ios.
- Prerequisites: Xcode 27, rustup with nightly + `rust-src`, cmake, xcodegen.

`arm64_32` is included in every build and labelled "compiles, not device-tested" (the test watch, a Series 9, runs arm64).

## 4. Reuse from element-x-ios

**Approach: copy and adapt, with provenance.** Files are copied into the same folder layout (`Services/<Feature>`, `Screens/<Screen>`, `FlowCoordinators/`, `Other/`) and recorded in `SHARED_FROM_IOS.md` with the source path, the element-x-ios commit (`ad1d7a301`) and a summary of changes. element-x-ios is not modified. A future upstream effort can turn the ledger into a shared package.

| Area | Treatment |
|---|---|
| `Services/Client` (`ClientProxy`, protocol) | Copy; remove Element Call, content scanner, Spaces, room directory. `AppSettings`/`NetworkMonitor` replaced by small watch equivalents. |
| `Services/Room` (joined-room proxy, summaries, room list service) | Copy; remove knocking, invite-only and space-specific code. |
| `Services/Timeline` (proxy, item content models, item factory) | Copy models and proxy; replace UIKit attributed-string rendering with SwiftUI `AttributedString` (bold/italic/links only); remove location, polls, voice recording, rich-text composer. |
| `Authentication`, `UserSession`, `Keychain`, `Users`, `SessionVerification`, `SecureBackup`, `Emojis` | Copy with minimal changes. QR login uses `LoginWithQrCodeHandler.generate()`. |
| `StateStoreViewModelV2`, `CoordinatorProtocol`, `NavigationStackCoordinator`, `StateMachine` | Copy as-is (same MVVM-C architecture as iOS). |
| Compound | Tokens only (colours, fonts, icons). Compound components are not used; screens use native watchOS controls styled with the tokens. |

Not copied: Element Call / NativeCall, Spaces, media upload, location, polls, rich-text editor, analytics, bug reporting, app lock, share extension.

## 5. Screens and navigation

Coordinators mirror iOS in reduced form:

- `AppCoordinator` → login flow or session flow, based on stored session.
- `AuthenticationFlowCoordinator` → QR login state machine.
- `UserSessionFlowCoordinator` → one `NavigationStack`: Chats → Chat → (image full-screen); Settings from the Chats toolbar.

### 5.1 QR login

States: **Start** ("Sign in with your iPhone" + instructions: *Element X → Settings → Link new device → Link desktop computer*) → **QR code** (full-screen, high contrast; rendered with a small pure-Swift QR encoder because CoreImage's generator is unavailable on watchOS) → **Enter check code** (2 digits via Digital Crown; `CheckCodeSender`) → **Approve on phone** (shows `user_code` from `WaitingForToken`) → **Syncing keys** → **Done** → Chats.
Errors (`HumanQrLoginError`: expired, declined, cancelled, not supported, etc.) show a clear message and "Try again".

Prerequisite on the phone: developer options (tap version 7× in Settings) → enable "Link new device" (`linkNewDeviceEnabled`).

### 5.2 Chats

- DMs + groups by recency from the SDK room list; spaces excluded; pending invites hidden.
- Row: avatar (initials fallback, thumbnail when loaded), name, one-line preview, timestamp, unread/mention badge.
- Offline/syncing banner driven by SDK sync state.
- Toolbar → **Settings**: display name, user ID, verification status, **Sign out**.

### 5.3 Chat (timeline)

- Opens at newest; Digital Crown scrolling; back-paginates at the top.
- Renders: text / emote / notice (bold, italic, links), image thumbnails (tap → full-screen), replies (quoted), reactions (chips), edited marker, redactions, UTD placeholder ("Waiting for this message", updates on key arrival). Most state events hidden; unsupported types show a compact placeholder.
- **Reply** button → system text input (dictation / Scribble / keyboard). Local echo with sending / failed (tap to retry).
- Long-press a message → quick reactions (👍 ❤️ 😂 😮 😢 🙏) + "Reply".
- Read receipts sent while the chat is visible.

Out of this sub-project: new chats, invites, room details/members, search, voice messages, media sending.

## 6. Data flow, lifecycle, errors

- **`URLSessionTransport`** (Swift `HttpTransport`): dedicated `URLSession` (cellular and expensive networks allowed, `waitsForConnectivity = false`); per-request timeout from the SDK, so long-poll sync requests aren't cut short; `URLError` → `HttpTransportError.Network` (SDK owns retry/backoff); logs method + path + status only — never bodies or tokens.
- **Storage:** SDK SQLite stores in Application Support, cache in Caches; session + store passphrase in the Keychain (`KeychainController`); OAuth token refresh persisted via `ClientSessionDelegate`. Client built with `systemIsMemoryConstrained()`.
- **Lifecycle:** `scenePhase == .active` → `SyncService.start()` (the list shows cached state immediately); inactive/background → `SyncService.stop()`. No background sync in this sub-project; notifications come from the iPhone's Element X, mirrored.
- **Crypto:** QR login delivers cross-signing + backup key, so the watch starts verified and downloads room keys from backup. No recovery-key entry on the watch.
- **Media:** server-side thumbnails sized for the watch (~2× point size) via the SDK, so they also go through the transport.
- **Errors:** offline → banner; send failure → per-message retry; session revoked or soft-logout → clear session, return to QR login; unexpected → toast + `.error` log.
- **Logging:** OSLog on the Swift side; Rust tracing to a rolling file in Caches, retrievable from Xcode's Devices window.

## 7. Testing

**Automated**
- SDK fork: requests are routed through a mock `HttpTransport`; transport errors yield `RetryKind::NetworkFailure`; OAuth and QR paths use the transport; the existing SDK test suite passes (reqwest default unchanged).
- Watch app (Swift Testing): view models, the QR login state machine, and `URLSessionTransport` against a `URLProtocol` stub (headers, body, status, timeout, error mapping). Sourcery mocks as on iOS.
- `PreviewProvider` previews for every screen state (snapshot tests deferred).

**Manual, on an Apple Watch Series 9 (testing session)**
1. With the iPhone in airplane mode (briefly online to scan and approve), the watch is on Wi-Fi/LTE. QR login succeeds and the watch reports itself verified.
2. The chats list shows DMs and groups with previews and badges.
3. An encrypted DM's history decrypts; back-pagination works.
4. A dictated reply sent with the phone off arrives on another client.
5. A reaction and a reply-to-message work.
6. Wrist down, receive messages, wrist up: the app catches up within seconds.
7. Sign out clears the session and returns to QR login.
8. The build including the `arm64_32` slice succeeds.

## 8. Definition of done

All automated tests pass; the manual checklist passes on the Series 9; the SDK fork's transport commits are clean and individually upstreamable; a fresh clone builds with `Tools/build-sdk.sh` → `xcodegen` → Xcode build.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Release binary size or memory too large for the watch | Measure early in the plan (release xcframework size, app memory on device); `systemIsMemoryConstrained()`; trim FFI features. |
| A reqwest bypass missed → silent failure on device | Keep the dead-port proxy tripwire in debug builds; the grep audit is part of the fork work. |
| The SDK fork drifts from upstream | Small commits; pin to the iOS-matched SDK commit; propose upstream after the testing session. |
| `arm64_32` runtime issues (32-bit pointers) | Labelled untested; test if an older watch becomes available. |
| Free Apple ID limits (7-day profiles, no push) | Accepted for this sub-project; paid account needed from sub-project 3. |

## 10. Future sub-project notes (not designed here)

- **Push:** the watch registers for APNs directly; self-hosted Sygnal with the user's APNs key; the pusher points at that gateway. watchOS supports notification service extensions for decrypting pushes.
- **Calls:** build on `matrix-rust-rtc` (native MatrixRTC; `MediaTransport` trait). Blocker: its LiveKit transport links libwebrtc, which has no watchOS build. Spike options: (A) port libwebrtc audio-only to watchOS, (B) a pure-Rust audio-only `MediaTransport` (webrtc-rs + Opus + LiveKit signalling + frame E2EE). CallKit on watchOS 9+ permits low-level networking during calls. Incoming calls need PushKit (paid account).
- **Sync with iPhone:** WatchConnectivity; scope to be defined.
