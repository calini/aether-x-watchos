# AGENTS.md — Element X watchOS

> Standalone watchOS Matrix client derived from element-x-ios. Spec: `docs/superpowers/specs/`. Plans: `docs/superpowers/plans/`.

## Build

1. SDK fork at `../matrix-rust-sdk` (branch `watchos-http-transport`). Build it into the local package: `Tools/build-sdk.sh --dev` (simulator only) or `Tools/build-sdk.sh` (simulator + devices, incl. arm64_32).
2. `xcodegen` — generates `ElementXWatch.xcodeproj` from `project.yml`. Never commit the project.
3. Mocks: `sourcery --config Tools/Sourcery/AutoMockableConfig.yml` (also runs as a build phase).
4. Tests: `xcodebuild test -project ElementXWatch.xcodeproj -scheme ElementXWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'`.
5. Device: copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`, set `DEVELOPMENT_TEAM`.

## Conventions (inherited from element-x-ios AGENTS.md)

- MVVM-Coordinator. Screen = `Models` / `ViewModelProtocol` / `ViewModel` (`StateStoreViewModelV2`) / `View` / `Coordinator`.
- Networking: **only** through `URLSessionTransport` (watchOS forbids sockets). Never use `Client.http_client()`-style reqwest paths.
- Default actor isolation is `MainActor`. Services doing background work are `nonisolated` + `Sendable`. Never add `@unchecked Sendable` / `nonisolated(unsafe)` by hand.
- Logging: `MXLog.info` default, `.error` for unexpected failures. Never log secrets or message content.
- Strings: `WatchStrings` enum (English only for now).
- Previews: `PreviewProvider`, every main state.
- Tests: Swift Testing. Test cases first, helpers below.
- Order in types: properties → `init` → functions. Views: properties → `init` → `body` → views → functions.
- Every file derived from element-x-ios gets a row in `SHARED_FROM_IOS.md`.
