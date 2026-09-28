# Aether X watchOS

A standalone Apple Watch client for [Matrix](https://matrix.org), built on the same [matrix-rust-sdk](https://github.com/matrix-org/matrix-rust-sdk) as [Element X iOS](https://github.com/element-hq/element-x-ios). It signs in, syncs, sends and receives on its own. Your iPhone doesn't need to be nearby.

**Status:** an early personal project (v0.3.0), sideloaded onto the author's Apple Watch. It isn't affiliated with or supported by Element.

**The name:** the aether was the classical fifth element, the medium that was thought to carry light and signals everywhere, owned by no one. That suits Matrix, where messages travel from your server to other people's servers with no centre in between. It was called Element X watchOS until v0.3.0, and was renamed so it isn't mistaken for an official Element app.

## How we got here

### Starting from Element X iOS

This isn't a from-scratch client. It is a new watchOS app that borrows as much of Element X iOS as a watch can use:

- **The same Rust core:** matrix-rust-sdk through its Swift bindings (`matrix-sdk-ffi`). It covers end-to-end encryption, sliding sync, the timeline, the send queue, media, QR login and live location.
- **The same app architecture:** MVVM-C screens (view, view model, coordinator), flow coordinators, `StateStoreViewModelV2`, Sourcery-generated mocks and Swift Testing.
- **The same design language:** Compound colour and icon tokens, and Element's app icon.
- **Ported code:** services and helpers copied from element-x-ios and adapted, with each one and its changes listed in [SHARED_FROM_IOS.md](SHARED_FROM_IOS.md). The screens are rebuilt for the watch: small, glanceable, Liquid Glass buttons, and Digital Crown support.

### What we swapped out, and why

A watch has different rules from a phone, so a few pieces had to be replaced:

| On Element X iOS | On the watch | Why |
|---|---|---|
| The SDK's own networking (reqwest, raw sockets) | A pluggable `HttpTransport` in the SDK, implemented with `URLSession` in the app | watchOS doesn't let apps open their own sockets outside audio or CallKit contexts ([TN3135](https://developer.apple.com/documentation/technotes/tn3135-low-level-networking-on-watchos)). Every request, including OAuth and QR-login rendezvous, goes through `URLSession`. |
| Prebuilt `MatrixRustSDK` package | The SDK fork [calini/matrix-rust-sdk](https://github.com/calini/matrix-rust-sdk), built locally for watchOS | The transport lives in the fork until it can go upstream (see below). |
| MapLibre maps | MapKit (`MKMapSnapshotter` previews, SwiftUI `Map`) | Built into watchOS, no extra dependency. |
| SwiftOGG + prebuilt libopus/libogg for voice messages | Apple's own Opus codec (`AVAudioConverter`) + a small Swift Ogg writer and reader | The prebuilt libraries exist only for iOS and macOS. The watch has an Opus codec, so only the Ogg file format was missing. Messages stay Ogg Opus, which Element X plays. |
| compound-ios (UIKit components, light and dark palettes) | Compound design tokens only, with the dark values as defaults | watchOS asset catalogs ignore the dark appearance, so the light colours showed up instead. [`Tools/make-compound-colors-dark.py`](Tools/make-compound-colors-dark.py) fixes that. |
| Sentry crash reporting | Compiled in but never started (or left out on the arm64_32 build) | It would open its own connections. |

### The SDK fork, and a side-step for older watches

The SDK changes live on two branches of the fork:

- **`watchos-http-transport`** (recommended). The smallest possible change: the opt-in HTTP transport, with no watch-specific hacks. Nothing changes for other platforms unless a transport is set. It builds for **64-bit (arm64) watches: Series 9 and later, and Ultra 2 and later**. It is also the starting point for a possible upstream contribution. Note that matrix-rust-sdk's [AI policy](https://github.com/matrix-org/matrix-rust-sdk/blob/main/CONTRIBUTING.md#ai-policy) means an upstream PR has to be written by a person; see [TODOS_WATCHOS.md](TODOS_WATCHOS.md).
- **`watchos-http-transport-arm64_32`** (a side-step). The same branch plus two fork-only commits, so the app also installs on **older watches that use the 32-bit-pointer `arm64_32` architecture: Apple Watch SE (2nd generation) and Series 6–8**:
  - a patched `constant_time_eq` crate, whose NEON code doesn't build for `arm64_32`;
  - an `xtask` option that leaves Sentry out of the build.

  This repo's `Tools/watchos-arm64_32.toolchain.cmake` also works around an `aws-lc-sys` build issue on that architecture. Supporting arm64 watches only would drop all of this.

`Tools/build-sdk.sh` works out which branch it is building and writes `Packages/MatrixRustSDK/SDKBuild.xcconfig`, so the app automatically builds for the right architectures.

## What it can do

A deliberately small feature set, chosen for a wrist:

- **Sign in:** pick a server (matrix.org by default), then sign in with a password, or with a QR code from Element X on a server that supports QR login.
- **Verify the watch:** compare emojis with another device, so encrypted history decrypts.
- **Chats:** direct messages and groups, with previews and unread markers. No Spaces.
- **Messages:**
  - read and send (dictation, the watch keyboard or the iPhone keyboard), reply and react;
  - pick quick reactions or any emoji;
  - retry failed messages.
- **Images:** view them full screen at the original resolution, and zoom with the Digital Crown.
- **Location:**
  - send your current location, or share it live for 15 minutes or 1 hour, with a Stop pill;
  - see other people's locations and live shares as maps.
- **Voice messages:**
  - record up to 5 minutes, review, then send;
  - play received voice messages.

## What's next

Details and smaller follow-ups are in [TODOS_WATCHOS.md](TODOS_WATCHOS.md).

### Push notifications

The watch only receives messages while the app is running. That covers wrist-up use, and background time during a live location share. Real push notifications need:

1. **A paid Apple Developer Program membership.** A free personal team can't use the push notifications entitlement (APNs).
2. **A push gateway for this app.** Element's push gateway only knows Element's own apps. A personal bundle ID needs its own gateway, e.g. [Sygnal](https://github.com/matrix-org/sygnal), set up with this app's APNs key.
3. **Registering a pusher** with the homeserver through the SDK, pointing at that gateway with the watch's APNs token. The session storage already has room for the pusher identifier.
4. **Decrypting notifications.** Most messages are end-to-end encrypted, so the notification has to be decrypted on the watch, the way Element X iOS does it in a notification service extension, before it can show the sender and message. The watchOS side of this still has to be worked out.

### Starting new DMs

Today you can only write in existing chats. Next is starting a direct message from the watch:
- search the homeserver's user directory;
- create the chat (the SDK supports this);
- keep typing short, using dictation or the iPhone keyboard.

### Audio calls

Calls come after that. watchOS allows real-time networking during calls (CallKit and audio contexts), so Matrix calls are feasible in principle. The first step is a spike comparing libwebrtc with a pure-Rust media transport for Element Call / MatrixRTC.

### Later

Syncing some state with the iPhone app, such as notification settings.

## Building

1. Clone the SDK fork next to this repo, or set `MATRIX_RUST_SDK_PATH`:
   ```bash
   git clone -b watchos-http-transport https://github.com/calini/matrix-rust-sdk ../matrix-rust-sdk
   ```
   For the SE (2nd generation) or Series 6–8, use `-b watchos-http-transport-arm64_32` instead.
2. Build the SDK with `Tools/build-sdk.sh`.
   - The full build covers the simulator and devices, and takes about 12 minutes.
   - `--dev` builds for the simulator only.
   - `--arm64-only` skips `arm64_32`. This is automatic on `watchos-http-transport`.
3. Generate the project with `xcodegen`, then open `AetherXWatch.xcodeproj`.
4. For a real watch, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set your Team ID. [TESTING.md](TESTING.md) explains how to find it. Run a Debug build with Sleep Focus off.

## More

- [TESTING.md](TESTING.md): install steps and the manual test checklist for the watch.
- [TODOS_WATCHOS.md](TODOS_WATCHOS.md): open work, the SDK fork, and the plan for upstreaming the transport to matrix-rust-sdk.
- [SHARED_FROM_IOS.md](SHARED_FROM_IOS.md): code taken from Element X iOS, and what changed.
- `docs/superpowers/`: the design specs and implementation plans behind each feature.

## Licence

AGPL-3.0; see [LICENSE](LICENSE). Code ported from Element X iOS keeps its original `AGPL-3.0-only OR LicenseRef-Element-Commercial` headers.
