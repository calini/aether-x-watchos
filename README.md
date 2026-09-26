# Element X watchOS

A standalone Apple Watch client for [Matrix](https://matrix.org), built on the same [matrix-rust-sdk](https://github.com/matrix-org/matrix-rust-sdk) as [Element X iOS](https://github.com/element-hq/element-x-ios). You can read and send messages from the watch without the phone nearby.

**Status:** early personal project (v0.1.0). It isn't affiliated with or supported by Element.

## What works

- Choose a server (matrix.org by default), then sign in with a password or a QR code from Element X on your iPhone (on servers that support QR login).
- Verify the watch by comparing emojis with another device, so encrypted history decrypts.
- A chats list of direct messages and groups (no Spaces).
- Read chats, send messages (dictation or keyboard), reply and react.

## How it works

watchOS only allows `URLSession` networking, so the app plugs a `URLSession`-based HTTP transport into the Rust SDK. The SDK changes are in the fork [calini/matrix-rust-sdk](https://github.com/calini/matrix-rust-sdk) (branch `watchos`). Files ported from Element X iOS are listed in [SHARED_FROM_IOS.md](SHARED_FROM_IOS.md).

## Building

1. Clone the SDK fork next to this repo on its `watchos` branch (or set `MATRIX_RUST_SDK_PATH`):
   ```bash
   git clone -b watchos https://github.com/calini/matrix-rust-sdk ../matrix-rust-sdk
   ```
2. Build the SDK for the watch with `Tools/build-sdk.sh`. The full build covers devices and takes about 12 minutes; `--dev` builds for the simulator only.
3. Generate the project with `xcodegen`, then open `ElementXWatch.xcodeproj`.
4. For a real watch, copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set your Team ID. [TESTING.md](TESTING.md) explains how to find it.

## More

- [TESTING.md](TESTING.md): install steps and the manual test checklist.
- [TODOS_WATCHOS.md](TODOS_WATCHOS.md): open work, the SDK fork, and the plan for upstreaming the transport to matrix-rust-sdk.
- `docs/superpowers/`: design specs and implementation plans.

## Licence

See [LICENSE](LICENSE).
