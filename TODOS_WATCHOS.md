# watchOS TODOs

Open work for Aether X watchOS, most important first. The SDK sections cover how the app depends on matrix-rust-sdk and what it would take to upstream that work.

## matrix-rust-sdk: fork and upstreaming

watchOS only lets apps use `URLSession` for networking; raw sockets aren't available outside audio and CallKit contexts ([TN3135](https://developer.apple.com/documentation/technotes/tn3135-low-level-networking-on-watchos)). The SDK normally talks HTTP through reqwest. The app instead needs a pluggable HTTP transport that it implements with `URLSession` (`AetherXWatch/Sources/Services/Transport/URLSessionTransport.swift`).

The SDK changes live in the fork [calini/matrix-rust-sdk](https://github.com/calini/matrix-rust-sdk), based on upstream `85bad975d`:

| Branch | Contents | Purpose |
|---|---|---|
| `watchos-http-transport` | The pluggable `HttpTransport` only: the client transport, OAuth and QR login routed through it, FFI exposure, and changelog entries. | Candidate PR to [matrix-org/matrix-rust-sdk](https://github.com/matrix-org/matrix-rust-sdk). Unused unless a transport is set, so other platforms keep using reqwest. What this app builds from by default: arm64 watches only, Sentry compiled in but never initialised. |
| `watchos-http-transport-arm64_32` | `watchos-http-transport` plus fork-only commits. | Optional app build for every watch, including arm64_32 (SE 2nd generation, Series 6–8), without Sentry. |

The app builds from either branch; `watchos-http-transport` is the default. On it, `build-sdk.sh` builds for arm64 watches only and with the SDK's default features, and writes `Packages/MatrixRustSDK/SDKBuild.xcconfig` (`ARCHS = arm64` for devices, `MATRIX_SDK_SENTRY` so `Tracing.swift` passes a nil `sentryConfig`).

### Upstreaming `watchos-http-transport`

> **Read upstream's [AI policy](https://github.com/matrix-org/matrix-rust-sdk/blob/main/CONTRIBUTING.md#ai-policy) first.** It requires disclosing AI help. Commit messages, PR text, docs and code comments must not be AI-generated. Using AI "in an autonomous-looking way", vibe coding or agent mode is not allowed at all. The commits on this branch were produced by AI agents, so they can't be submitted as they are. Treat the branch as a working prototype and a reference, not as the PR.

- [ ] Open an issue upstream in your own words describing the watchOS constraint (URLSession only, TN3135) and the opt-in transport design. Ask whether the maintainers want it and how they'd like it contributed.
- [ ] If they're open to it, write the upstream change yourself from the prototype, with your own commit messages, docs and PR description, a plain AI disclosure, and a DCO sign-off (`git commit -s`) on every commit.
- [ ] Before submitting, deal with what a review of the prototype found:
  - It's 87 commits behind `main` and conflicts with it: in the OAuth HTTP client, the MSC4108 rendezvous channel, the secure channel and `error.rs`. Upstream has also replaced `assert_matches2`.
  - Document which reqwest-only builder settings stop applying once a custom transport is set: proxy, user agent, disabling SSL verification, root certificates, `http_client`, and the timeouts. Note too that `Client::http_client()` bypasses the transport.
  - Use `#[async_test]` rather than `#[tokio::test]` in `matrix-sdk`.
  - Consider changing `TransportError(pub String)` to a boxed source error or a private field, and naming it `HttpTransportError`. Consider `Option<Duration>` for the FFI timeout.
  - The new `HttpError::Transport` variant is a breaking change, and it has no non-breaking alternative. Flag it with a `[**breaking**]` changelog fragment.
  - Name the changelog fragments after the PR number (they're `XXXX.*.md` for now).
  - Add tests for the rendezvous PUT with `If-Match`, for retrying after a transport failure, and for FFI `get_url` going through the transport.
- [ ] Keep the upstream change to the transport only. Everything watch-specific stays on `watchos-http-transport-arm64_32`.

### Fork-only commits on `watchos-http-transport-arm64_32`

Without them (the default `watchos-http-transport` build), the app runs on arm64 watches only and has Sentry compiled in but never initialised.

- **`feat(xtask)`: choose the matrix-sdk-ffi features for Swift frameworks.** `build-sdk.sh` passes `--features ""` to leave out Sentry, which would open its own sockets. It's a small, generic xtask option, so it could be proposed upstream as a separate PR. Alternatives: `build-sdk.sh` could call cargo and uniffi-bindgen directly, or Sentry could stop being a default feature upstream.
- **`chore`: patch `constant_time_eq` for `arm64_32` watchOS.** This only matters for the `arm64_32` slice, which covers the older watches that can run watchOS 11 and later (Series 6–8 and SE). The crate's NEON code isn't limited to 64-bit pointers, so it doesn't build for `arm64_32`. The fork vendors a patched copy (`contrib/patches/constant_time_eq`, wired via `[patch]`). Options:
  - Send the one-line `target_pointer_width = "64"` cfg fix to the `constant_time_eq` crate, then drop the vendored copy once it's released.
  - **Or support 64-bit `arm64` watches only** (Series 9 and later, Ultra 2 and later, on watchOS 26). That removes this patch, the `arm64_32` slice, `Tools/watchos-arm64_32.toolchain.cmake`, and the `aws-lc-sys` workaround below. It also cuts build time and app size. The cost: older watches can't run the app.

The old `watch` Cargo profile has moved out of the SDK. The `aws-lc-sys` build workaround for `arm64_32` (no assembly) now lives in this repo's `Tools/watchos-arm64_32.toolchain.cmake`, and the SDK builds with its stock `reldbg` profile.

### Publish a prebuilt SDK package (like element-x-ios)

- [ ] Today anyone building the app needs Rust, the SDK fork and about 12 minutes of `Tools/build-sdk.sh`.
- element-x-ios instead pins `MatrixRustSDK` to [element-hq/matrix-rust-components-swift](https://github.com/element-hq/matrix-rust-components-swift) with `exactVersion` in `project.yml`: a Swift package whose `binaryTarget` points at a zipped xcframework attached to a GitHub release (URL + checksum), plus the generated Swift bindings. `swift run tools build-sdk` only switches to a local build (clones `../matrix-rust-sdk`, symlinks it as `matrix-rust-components-swift`, rewrites `project.yml`, reruns xcodegen).
- Plan: publish our own components package (e.g. `calini/matrix-rust-components-swift`) with the watchOS xcframework (per SDK mode) as release assets, pin it in `project.yml`, and make `build-sdk.sh` the opt-in local-development path. Best done once the SDK side settles.

### Known SDK-side issues

- [ ] Room list teardown: a tokio `TaskHandle` abort doesn't wait for an in-flight poll, so the `RoomList` can be dropped mid-poll on sign-out. The iOS app has the same window. The fix belongs in the SDK (field order, or the task holding an `Arc`).
- [ ] Swift task cancellation doesn't reach Rust futures (the uniffi bindings don't bridge it). A cancelled QR attempt keeps its rendezvous open until the SDK times out; cleanup is still correct.

## App follow-ups

### Verification

- [ ] The controller-loading timeout can fire right as the controller arrives (around 30 s), showing "failed" over a request that's already in flight. Check `Task.isCancelled` after the timeout's sleep.
- [ ] Log the outcome of the server identity fallback in `ClientProxy.sessionVerificationController()`, and reset the "logged once" flag after a success.
- [ ] A quick Try again after a failure can be flipped to "failed" by the previous attempt's late result. Use per-attempt tokens instead of comparing steps.
- [ ] Answer verification requests started from other devices.
- [ ] QR-code verification (needs FFI surface in the SDK).
- [ ] Recovery-key entry.

### Location sharing

Watch these on the device first:
- [ ] Tapping Stop within about 30 s of starting a share, then lowering the wrist, may only stop the share on the server late. The pending stop retry doesn't keep sync running by itself; if it shows up, have the service publish a `needsSync` that covers pending stops. The share still ends at its expiry.
- [ ] Indoors, a one-off location request can fail straight away on a transient `locationUnknown` error when no live share is running.
- [ ] Opening a chat waits for the room's live-location observer to load; check how long that takes on the device.

Edge cases:
- [ ] Location access revoked while a share is still starting isn't handled, only after it has started.
- [ ] A same-room restart drops the old share's pending stop; if the new start then fails, the old share stays live until it expires.
- [ ] Right after a restart, a narrow restore/start window can leave the old share live beside the new one until it expires.
- [ ] The own-bubble Stop isn't matched to this watch's beacon, so it can stop the watch's share from a message sent by another device in the same room. Expose the beacon ID in `.sharing`.
- [ ] A share confirmed late can wait up to 30 s extra before its first update.
- [ ] A non-live own-beacon update doesn't end a pending stop's 30 s confirmation wait.
- [ ] `LocationAuthorization` has no `.restricted` case.

Polish:
- [ ] The minute tick redraws the chat even when nothing is live.
- [ ] The paused pill hides the time left.
- [ ] The pill's backing is 0.9 opacity.
- [ ] `RoundStopButtonStyle` and `SmallGlassButtonStyle` are near-duplicates.
- [ ] The snapshot pin uses `UIColor.red` / `.white`, not Compound colours.
- [ ] The Location sheet previews have no busy or error-alert state.
- [ ] Tapping a failed own location opens the map instead of retrying.
- [ ] A cached map coordinator outlives its screen.
- [ ] An in-flight locate isn't cancelled when the sheet closes.
- [ ] `WatchStrings.locationTitle` duplicates `WatchStrings.location`.

Tests:
- [ ] A test for a double tap while busy on every Location sheet action.
- [ ] Unit tests for `RoomSummaryPreview` "📍 Location" / "📍 Live location".
- [ ] The locale test mutates the global `setlocale`.
- [ ] Other older `\(error)` logs in `ClientProxy` (media, timeline, logout).

### Voice messages

Watch these on the device first (TESTING V1–V15):
- [ ] The 4:30 haptic while recording. Haptics are now allowed during recording, but only a real watch can confirm it.
- [ ] Battery while a message plays. The chat re-renders about 10 times a second; if that's costly, scope the progress to the playing bubble.
- [ ] Whether the chat's `onDisappear` stops playback when a sheet opens (long-pressing a playing message), and whether ✕ during recording is caught.
- [ ] AirPods routing with the `.playback` category and the default policy.

Follow-ups:
- [ ] Cap the download size before downloading. The 5 MB check runs after the file is in memory, and an earlier cap needs `MediaLoader`/SDK support.
- [ ] The 5:00 limit relies on the tick task. Use `record(forDuration:)` as a backstop and treat a successful finish as a stop.
- [ ] Recordings are Float32 (57.6 MB for 5 min); 16-bit would halve that.
- [ ] Messages over about 3.5 min decode larger than the 20 MB cache and evict everything else.
- [ ] `VoiceMessageCache.removeAll()` runs on the main actor at sign-out.
- [ ] Tapping ▶︎ in the moment between a natural end and its finish callback can leave the state idle while audio plays.
- [ ] Spurious `.error` logs when a preview decode is cancelled.
- [ ] The failed-playback icon is Compound's `errorSolid` (a red "!"), not the ⚠︎ in the spec.
- [ ] The Ogg reader doesn't validate page sequence numbers.
- [ ] The packet cap also limits the OpusTags size, so there's no cover art.
- [ ] Tests: two 50 ms negative-assertion sleeps; the clear-cache-during-decode race is untested; a stray blank line in `VoiceMessagePreviewPlayerTests`.
- [ ] Cleanups: the `onChunkRead` parameter; the audio-support model isn't DEBUG-gated; the voice emoji is built at two call sites; `TimelineProxy` re-reads the size; the writer clamps granules instead of asserting.

### UI polish

- [ ] The Verify sheet content goes blank while it animates away.
- [ ] A verification fetch that completes during sign-out can briefly show the sheet.
- [ ] The "Empty" password-screen preview prefills the username.

### Tests and hygiene

- [ ] Missing tests:
  - `SlidingSyncVersion` → "This server isn't supported.";
  - a late proxy failure after Cancel staying cancelled;
  - method-screen action wiring and partial pops;
  - the sheet's swipe-down binding;
  - the emoji-free log description.
- [ ] Flakiness guards:
  - `startingTwiceSubscribesOnce` needs `withExtendedLifetime`;
  - `AuthenticationServiceTests` should wait on `ReceivedInvocations.count` rather than `CallsCount`.
- [ ] Cosmetic: `LoginMethodScreenCoordinator.context` is unused; there's a long line in `ClientProxy.swift`; there's a stray blank line in `AuthenticationFlowCoordinatorTests.swift`.
- [ ] Transport-error test: also assert the stubbed transport was actually hit, since every `HttpError` maps to "server unreachable".
- [ ] `StubURLProtocol` shares global state across suites. Add `-parallel-testing-enabled NO` to the test command in AGENTS.md, or put the suites that use the stub under one serialized parent.
- [ ] `Tools/watchos-arm64_32.toolchain.cmake` applies to every crate built with CMake for `arm64_32`, not just `aws-lc-sys`. Fix its comment.
- [ ] Update the `App:` commit in TESTING.md to the build that's actually tested.
- [ ] The `constant_time_eq` patch also bumps the crate from 0.4.2 to 0.4.3. Say so in that commit's message.

## Roadmap

1. Push notifications. Needs a paid Apple developer account for APNs.
2. Starting new DMs.
3. Audio calls. Spike first: libwebrtc vs. a pure-Rust transport for matrix-rust-rtc.
4. Syncing with the iPhone app (notifications, settings).
