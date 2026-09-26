# AGENTS.md — Element X watchOS

> Standalone watchOS Matrix client derived from element-x-ios. Spec: `docs/superpowers/specs/`. Plans: `docs/superpowers/plans/`.

## Build

1. SDK fork at `../matrix-rust-sdk` (override with `MATRIX_RUST_SDK_PATH`), branch `watchos` of https://github.com/calini/matrix-rust-sdk: the upstream PR branch `watchos-http-transport` plus fork-only commits (xtask `--features`, `constant_time_eq` arm64_32 patch). Build it into the local package: `Tools/build-sdk.sh --dev` (simulator only, `dev` profile) or `Tools/build-sdk.sh` (simulator + devices, incl. arm64_32, SDK's `reldbg` profile). For arm64_32 only, the full build forces `aws-lc-sys`'s cmake builder and points it at `Tools/watchos-arm64_32.toolchain.cmake`, which sets the right arch (its own builder mislabels arm64_32 objects as arm64, which fails to lipo) and `OPENSSL_NO_ASM` (aws-lc's assembly assumes 64-bit words; `AWS_LC_SYS_NO_ASM` would demand opt-level 0).
2. `xcodegen` — generates `ElementXWatch.xcodeproj` from `project.yml`. Never commit the project.
3. Mocks: `sourcery --config Tools/Sourcery/AutoMockableConfig.yml` (also runs as a build phase).
4. Tests: `xcodebuild test -project ElementXWatch.xcodeproj -scheme ElementXWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.5'`. Pin `OS=26.5`. Both sims skip `URLProtocol` stubs for PUT/POST (so stubbed tests use GET only, see `URLSessionTransportTests`); the watchOS 27.0 sim also skips them for `session.data(for:)`, so its transport tests fail. 26.5 matches the real test device (Series 9, watchOS 26).
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
