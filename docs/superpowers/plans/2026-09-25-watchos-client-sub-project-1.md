# Element X watchOS — Sub-project 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A standalone watchOS Matrix client that signs in by QR code from Element X iOS, lists DMs and groups, shows decrypted timelines, and sends replies and reactions without the iPhone being reachable.

**Architecture:** The full matrix-rust-sdk (`matrix-sdk-ffi`) runs on the watch. A new pluggable `HttpTransport` in a fork of the SDK routes every HTTP request through a Swift `URLSession` implementation, because watchOS forbids raw sockets. The watch app follows Element X iOS's MVVM-Coordinator architecture, with slimmed service proxies derived from element-x-ios and native watchOS SwiftUI screens styled with Compound design tokens.

**Tech Stack:** Rust (nightly, `-Zbuild-std`, uniffi 0.32), matrix-rust-sdk fork, Swift 6.2 / SwiftUI / watchOS 11, XcodeGen, Swift Testing, Sourcery, `swift-qrcode-generator`.

**Spec:** `docs/superpowers/specs/2026-09-25-watchos-client-design.md` (same repo). Read it before starting any task.

## Global Constraints

- Repos (siblings under `~/Developer/git/github.com/element-hq/`): `element-x-watchos` (this repo), `matrix-rust-sdk` (fork, branch `watchos-http-transport`), `element-x-ios` (**read-only — never modify**).
- SDK fork base commit: `85bad975d462be6578964991905e8e9bf8314a6f`. element-x-ios reference commit: `ad1d7a301`.
- Rust targets built for the watch: `aarch64-apple-watchos`, `arm64_32-apple-watchos`, `aarch64-apple-watchos-sim`. watchOS deployment target: `11.0` everywhere (Rust and Xcode).
- Watch SDK builds use `AWS_LC_SYS_NO_ASM=1` and **must not** enable the FFI `sentry` feature.
- reqwest stays the SDK default: with no transport set, behaviour must be byte-for-byte what it was (iOS is unaffected).
- Generated Swift bindings compile in **Swift 5 language mode** (local package, `swift-tools-version:5.9`). App code: `SWIFT_VERSION 6.2`, `SWIFT_APPROACHABLE_CONCURRENCY YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION MainActor`.
- Bundle ID: `io.ilie.elementx.watch` (watch-only app, `WKWatchOnly = YES`). Unit-test bundle: `io.ilie.elementx.watch.unittests`.
- Licence: code derived from element-x-ios / compound-design-tokens keeps its `SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial` header; the repo ships the AGPL `LICENSE`.
- Every file copied or derived from element-x-ios gets a row in `SHARED_FROM_IOS.md` (source path, `ad1d7a301`, what changed).
- Logging: `MXLog.info` by default, `.error` for unexpected failures. **Never log secrets, tokens, passphrases, request/response bodies or message content.** Matrix IDs are fine.
- Strings: this sub-project hard-codes English strings in a single `WatchStrings.swift` enum (no Localazy/`L10n` yet).
- Previews use `PreviewProvider` and cover every main state of each screen.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`). Test cases first, helpers below.
- Member order in types: properties → `init` → functions. Views: properties → `init` → `body` → other views → functions.
- Commits: title + description, ending with the two attribution lines:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX
  ```
- Standard test command for the watch app (used by every Swift task):
  ```bash
  cd ~/Developer/git/github.com/element-hq/element-x-watchos
  xcodebuild test -project ElementXWatch.xcodeproj -scheme ElementXWatch \
    -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
    -parallel-testing-enabled NO 2>&1 | tail -30
  ```
  Add `-only-testing:UnitTests/<SuiteName>` to run one suite. Parallel testing stays off because `StubURLProtocol` is process-wide.
- Standard Rust test command (used by every SDK task): `cd ~/Developer/git/github.com/element-hq/matrix-rust-sdk && cargo test -p matrix-sdk --lib <filter>` (host target; no watch toolchain needed for tests).

## Review Focus

1. **A request that bypasses the transport.** Any SDK path that still calls reqwest works in the simulator but fails on a real watch. Expect: in DEBUG builds the reqwest proxy points at `http://127.0.0.1:9`, so a bypass fails loudly. Pinned by the tripwire in Task 10, plus the transport-routing tests in Tasks 2–4.
2. **Long-poll sync cut short by a `URLSession` timeout.** A sync request that holds the connection open for ~30 s must not be killed at 60 s defaults or sooner. Expect: the per-request SDK timeout wins, and a missing timeout falls back to 120 s. Pinned by a `URLSessionTransport` test in Task 8.
3. **The app relaunched after the Rust store or keychain entry is gone** (reinstall, or sign-out mid-way). Expect: the app lands on QR login, never crashes, and never shows an empty chat list forever. Pinned by `SessionStore` tests in Task 9 and `AppCoordinator` tests in Task 18.
4. **QR login interrupted** (the phone declines, the code expires, the user backs out or enters the wrong check code). Expect: a specific error message and "Try again", which starts a fresh flow with a fresh QR code. Pinned by the `QRLoginScreenViewModel` tests in Task 14.
5. **A message that fails to send** (offline, or rejected). Expect: a visible failed state and tap-to-retry, never a silently dropped message. Pinned by `ChatScreenViewModel` tests in Task 17.

---

## Phase A — SDK fork (`~/Developer/git/github.com/element-hq/matrix-rust-sdk`)

### Task 1: Fork setup, arm64_32 fix, feature-selectable xtask build

**Files:**
- Create: `contrib/patches/constant_time_eq/` (vendored crate `constant_time_eq` 0.4.3 with a one-line cfg fix)
- Modify: `Cargo.toml` (workspace `[patch.crates-io]`)
- Modify: `xtask/src/swift.rs` (new `--features` option for `build-framework`)

**Interfaces:**
- Produces: `cargo xtask swift build-framework --features <list>` (overrides the hard-coded `FFI_FEATURES = "sentry"`; omitting `--features` keeps `sentry`, so upstream behaviour is unchanged). An empty string (`--features ""`) builds with default features only.

- [ ] **Step 1: Clone and branch**

```bash
cd ~/Developer/git/github.com/element-hq
git clone https://github.com/matrix-org/matrix-rust-sdk.git
cd matrix-rust-sdk
git switch -c watchos-http-transport 85bad975d462be6578964991905e8e9bf8314a6f
```

Expected: `Switched to a new branch 'watchos-http-transport'`. (The user adds their GitHub fork as a remote later; do not push.)

- [ ] **Step 2: Install toolchain prerequisites (skip any already present)**

```bash
command -v rustup || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal
~/.cargo/bin/rustup toolchain install nightly --profile minimal --component rust-src
brew list cmake >/dev/null 2>&1 || brew install cmake
```

- [ ] **Step 3: Reproduce the arm64_32 failure (the "failing test")**

```bash
export PATH=$HOME/.cargo/bin:/opt/homebrew/bin:$PATH DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
AWS_LC_SYS_NO_ASM=1 cargo +nightly build -Zbuild-std -p matrix-sdk-ffi --target arm64_32-apple-watchos --lib 2>&1 | grep -E "^error" | head -3
```

Expected: `error[E0308]: mismatched types` in `constant_time_eq-0.4.x/src/neon.rs` (`expected u32, found u64`).

- [ ] **Step 4: Vendor and fix `constant_time_eq`**

```bash
cargo update -p constant_time_eq --precise 0.4.3
mkdir -p contrib/patches
cp -R ~/.cargo/registry/src/index.crates.io-*/constant_time_eq-0.4.3 contrib/patches/constant_time_eq
rm -f contrib/patches/constant_time_eq/.cargo_vcs_info.json
sed -i '' 's/all(target_arch = "aarch64", target_feature = "neon", not(miri))/all(target_arch = "aarch64", target_pointer_width = "64", target_feature = "neon", not(miri))/g' contrib/patches/constant_time_eq/src/lib.rs
grep -c 'target_pointer_width = "64", target_feature = "neon"' contrib/patches/constant_time_eq/src/lib.rs
```

Expected: `3`.

Then add this line as the **first entry** under the existing `[patch.crates-io]` table in the root `Cargo.toml` (do not create a second `[patch.crates-io]` header):

```toml
constant_time_eq = { path = "contrib/patches/constant_time_eq" }
```

- [ ] **Step 5: Add a `--features` option to the xtask**

In `xtask/src/swift.rs`, add a field to the `BuildFramework` variant of `SwiftCommand` (after `sequentially`):

```rust
        /// Cargo features to enable for matrix-sdk-ffi, overriding the default
        /// (`sentry`). Pass an empty string to build with default features only.
        #[clap(long)]
        features: Option<String>,
```

Thread it through to `build_xcframework` as a new last parameter `features: Option<&str>` (update the `match` arm that destructures `BuildFramework` and the call site). Inside `build_xcframework` and every helper that currently interpolates `FFI_FEATURES` (the `cmd!` invocations and the `.arg("--features").arg(FFI_FEATURES)` calls), use:

```rust
let ffi_features = features.unwrap_or(FFI_FEATURES);
```

and pass `ffi_features` wherever `FFI_FEATURES` was used. When `ffi_features` is empty, skip adding `--features` entirely:

```rust
if !ffi_features.is_empty() {
    cmd = cmd.arg("--features").arg(ffi_features);
}
```

For the `cmd!` macro invocations that embed `--features {FFI_FEATURES}` in the string, split them the same way: build the command without `--features`, then append `.arg("--features").arg(ffi_features)` only when non-empty.

- [ ] **Step 6: Verify all three watch targets build**

```bash
export PATH=$HOME/.cargo/bin:/opt/homebrew/bin:$PATH DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
for t in aarch64-apple-watchos-sim aarch64-apple-watchos arm64_32-apple-watchos; do
  AWS_LC_SYS_NO_ASM=1 cargo +nightly build -Zbuild-std -p matrix-sdk-ffi --target $t --lib 2>&1 | tail -1
done
cargo run -p xtask -- swift build-framework --help | grep -A2 -- "--features"
```

Expected: three `Finished \`dev\` profile` lines, and the help text shows `--features`.

- [ ] **Step 7: Commit**

```bash
git add Cargo.toml Cargo.lock contrib/patches/constant_time_eq xtask/src/swift.rs
git commit -m "Build matrix-sdk-ffi for arm64_32 watchOS and allow selecting FFI features

Vendors constant_time_eq 0.4.3 with its NEON path restricted to 64-bit
pointer widths (arm64_32 has 32-bit words), and adds --features to
xtask build-framework so watchOS builds can omit Sentry.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

### Task 2: `HttpTransport` trait routed through `HttpClient`

**Files:**
- Create: `crates/matrix-sdk/src/http_client/transport.rs`
- Modify: `crates/matrix-sdk/src/http_client/mod.rs` (module decl, `transport` field, `with_transport`, `execute_raw`)
- Modify: `crates/matrix-sdk/src/http_client/native.rs` (use the transport in `send_request_inner`; `execute_raw`)
- Modify: `crates/matrix-sdk/src/http_client/wasm.rs` (`execute_raw` for wasm, reqwest only)
- Modify: `crates/matrix-sdk/src/error.rs` (`HttpError::Transport`, retry kind)
- Modify: `crates/matrix-sdk/src/lib.rs` (re-exports)
- Modify: `crates/matrix-sdk/src/client/builder/mod.rs` (`http_transport` option)
- Modify: `crates/matrix-sdk/src/client/mod.rs` (`Client::send_raw_request`)

**Interfaces:**
- Produces (public, `matrix_sdk::`):
  ```rust
  pub trait HttpTransport: SendOutsideWasm + SyncOutsideWasm + std::fmt::Debug {
      fn execute(&self, request: http::Request<Bytes>, timeout: Option<Duration>)
          -> BoxFuture<'static, Result<http::Response<Bytes>, TransportError>>;
  }
  pub struct TransportError(pub String); // thiserror, Display "HTTP transport error: {0}"
  impl ClientBuilder { pub fn http_transport(self, transport: Arc<dyn HttpTransport>) -> Self }
  impl Client { pub async fn send_raw_request(&self, request: http::Request<Bytes>) -> Result<http::Response<Bytes>, HttpError> }
  HttpError::Transport(TransportError)  // RetryKind::NetworkFailure
  ```
- Produces (crate-internal): `HttpClient::transport: Option<Arc<dyn HttpTransport>>`, `HttpClient::with_transport(self, Option<Arc<dyn HttpTransport>>) -> Self`, `HttpClient::execute_raw(&self, request: http::Request<Bytes>, timeout: Option<Duration>) -> Result<http::Response<Bytes>, HttpError>`.

- [ ] **Step 1: Write the failing tests**

Create `crates/matrix-sdk/src/http_client/transport.rs` with only the test module for now:

```rust
#[cfg(all(test, not(target_family = "wasm")))]
mod tests {
    use std::{
        sync::{Arc, Mutex},
        time::Duration,
    };

    use assert_matches2::assert_matches;
    use bytes::Bytes;
    use matrix_sdk_base::BoxFuture;

    use super::{HttpTransport, TransportError};
    use crate::{Client, HttpError, config::RequestConfig};

    #[tokio::test]
    async fn test_requests_go_through_the_transport() {
        let transport = RecordingTransport::responding_with(200, r#"{"versions":["v1.11"]}"#);
        let client = client_with(transport.clone()).await;

        let versions = client.server_versions().await.expect("versions request should succeed");

        assert!(!versions.is_empty());
        assert_eq!(transport.recorded_paths(), vec!["/_matrix/client/versions".to_owned()]);
    }

    #[tokio::test]
    async fn test_transport_errors_are_network_failures() {
        let transport = RecordingTransport::failing();
        let client = client_with(transport.clone()).await;

        let error = client.server_versions().await.expect_err("request should fail");

        assert_matches!(error, HttpError::Transport(TransportError(message)));
        assert_eq!(message, "offline");
        assert_matches!(
            HttpError::Transport(TransportError("x".to_owned())).retry_kind(),
            crate::error::RetryKind::NetworkFailure
        );
    }

    #[tokio::test]
    async fn test_raw_requests_go_through_the_transport() {
        let transport = RecordingTransport::responding_with(204, "");
        let client = client_with(transport.clone()).await;
        let request = http::Request::get("https://example.org/raw").body(Bytes::new()).unwrap();

        let response = client.send_raw_request(request).await.expect("raw request should succeed");

        assert_eq!(response.status(), 204);
        assert_eq!(transport.recorded_paths(), vec!["/raw".to_owned()]);
    }

    // MARK: - Helpers

    async fn client_with(transport: Arc<RecordingTransport>) -> Client {
        Client::builder()
            .homeserver_url("https://example.org")
            .request_config(RequestConfig::new().disable_retry())
            // Any request that escapes the transport fails on this closed port.
            .proxy("http://127.0.0.1:9")
            .http_transport(transport)
            .build()
            .await
            .expect("client should build")
    }

    #[derive(Debug)]
    struct RecordingTransport {
        response: Option<(u16, &'static str)>,
        paths: Mutex<Vec<String>>,
    }

    impl RecordingTransport {
        fn responding_with(status: u16, body: &'static str) -> Arc<Self> {
            Arc::new(Self { response: Some((status, body)), paths: Mutex::new(Vec::new()) })
        }

        fn failing() -> Arc<Self> {
            Arc::new(Self { response: None, paths: Mutex::new(Vec::new()) })
        }

        fn recorded_paths(&self) -> Vec<String> {
            self.paths.lock().unwrap().clone()
        }
    }

    impl HttpTransport for RecordingTransport {
        fn execute(
            &self,
            request: http::Request<Bytes>,
            _timeout: Option<Duration>,
        ) -> BoxFuture<'static, Result<http::Response<Bytes>, TransportError>> {
            self.paths.lock().unwrap().push(request.uri().path().to_owned());
            let response = self.response;
            Box::pin(async move {
                let (status, body) = response.ok_or_else(|| TransportError("offline".to_owned()))?;
                Ok(http::Response::builder()
                    .status(status)
                    .header("content-type", "application/json")
                    .body(Bytes::from_static(body.as_bytes()))
                    .unwrap())
            })
        }
    }
}
```

Add `mod transport;` to `crates/matrix-sdk/src/http_client/mod.rs` (directly above `#[cfg(not(target_family = "wasm"))] mod native;`).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cargo test -p matrix-sdk --lib http_client::transport 2>&1 | grep -E "^error" | head -5`
Expected: compile errors: `cannot find trait HttpTransport`, `no method named http_transport`, `no method named send_raw_request`.

- [ ] **Step 3: Implement the trait**

Prepend to `transport.rs`:

```rust
//! A pluggable HTTP transport, for platforms where the SDK must not open its
//! own sockets (e.g. watchOS, where only `URLSession` is permitted).

use std::{fmt::Debug, time::Duration};

use bytes::Bytes;
use matrix_sdk_base::{BoxFuture, SendOutsideWasm, SyncOutsideWasm};

/// Sends fully-buffered HTTP requests on behalf of the SDK.
///
/// When set with [`ClientBuilder::http_transport`](crate::ClientBuilder::http_transport),
/// every request the client makes goes through this transport instead of
/// the built-in reqwest client.
pub trait HttpTransport: SendOutsideWasm + SyncOutsideWasm + Debug {
    /// Execute `request`, returning the full response. `timeout` is the
    /// SDK's timeout for this request, if any.
    fn execute(
        &self,
        request: http::Request<Bytes>,
        timeout: Option<Duration>,
    ) -> BoxFuture<'static, Result<http::Response<Bytes>, TransportError>>;
}

/// A network-level failure reported by an [`HttpTransport`].
#[derive(Debug, thiserror::Error)]
#[error("HTTP transport error: {0}")]
pub struct TransportError(pub String);
```

In `http_client/mod.rs`, below `mod transport;`:

```rust
pub use transport::{HttpTransport, TransportError};
```

Add the field and helper to `HttpClient` (the struct keeps `#[derive(Clone, Debug)]`):

```rust
#[derive(Clone, Debug)]
pub(crate) struct HttpClient {
    pub(crate) inner: reqwest::Client,
    pub(crate) transport: Option<Arc<dyn HttpTransport>>,
    pub(crate) request_config: RequestConfig,
    concurrent_request_semaphore: MaybeSemaphore,
    next_request_id: Arc<AtomicU64>,
}
```

In `HttpClient::new`, initialise `transport: None,`. Add after `new`:

```rust
    pub(crate) fn with_transport(mut self, transport: Option<Arc<dyn HttpTransport>>) -> Self {
        self.transport = transport;
        self
    }
```

- [ ] **Step 4: Route requests through the transport (native)**

In `http_client/native.rs`, change the inner helper's first parameter and body:

```rust
        async fn send_request_inner(
            http_client: &HttpClient,
            request: &http::Request<Bytes>,
            timeout: Option<Duration>,
            retry_count: &AtomicU64,
            send_progress: SharedObservable<TransmissionProgress>,
        ) -> HttpResult<http::Response<Bytes>> {
            let num_attempt = retry_count.fetch_add(1, Ordering::SeqCst);
            debug!(num_attempt, "Sending request");
            let before = ruma::time::Instant::now();

            let response = match &http_client.transport {
                Some(transport) => transport.execute(request.clone(), timeout).await?,
                None => {
                    execute_request(&http_client.inner, request, timeout, send_progress).await?
                }
            };
```

(Keep the rest of the helper unchanged.) At its call site change `&self.inner,` to `self,`.

Add to the `impl HttpClient` block in `native.rs`:

```rust
    /// Send an arbitrary, already-built request, honouring the custom
    /// transport. No retries, no Matrix-specific response parsing.
    pub(crate) async fn execute_raw(
        &self,
        request: http::Request<Bytes>,
        timeout: Option<Duration>,
    ) -> Result<http::Response<Bytes>, HttpError> {
        match &self.transport {
            Some(transport) => Ok(transport.execute(request, timeout).await?),
            None => execute_request(&self.inner, &request, timeout, Default::default()).await,
        }
    }
```

In `http_client/wasm.rs`, add the wasm equivalent (reqwest only; the transport is not used on wasm):

```rust
impl HttpClient {
    pub(crate) async fn execute_raw(
        &self,
        request: http::Request<Bytes>,
        _timeout: Option<std::time::Duration>,
    ) -> Result<http::Response<Bytes>, HttpError> {
        let request = reqwest::Request::try_from(request)?;
        Ok(response_to_http_response(self.inner.execute(request).await?).await?)
    }
}
```

- [ ] **Step 5: Error variant**

In `crates/matrix-sdk/src/error.rs`, add after the `Reqwest` variant of `HttpError`:

```rust
    /// Error reported by a custom [`HttpTransport`](crate::HttpTransport).
    #[error(transparent)]
    Transport(#[from] crate::http_client::TransportError),
```

and in `retry_kind` change the first arm to:

```rust
            HttpError::Reqwest(_) | HttpError::Transport(_) => RetryKind::NetworkFailure,
```

Make `RetryKind` and `retry_kind` reachable from the test (`pub(crate)` already; the test lives in the same crate, so no change is needed if both are `pub(crate)`).

- [ ] **Step 6: Builder option, raw request API, re-exports**

In `crates/matrix-sdk/src/lib.rs` change the `pub use http_client::{…}` line to:

```rust
pub use http_client::{
    HttpTransport, SupportedAuthScheme, SupportedPathBuilder, TransmissionProgress, TransportError,
};
```

In `client/builder/mod.rs`: add a field `http_transport: Option<Arc<dyn crate::HttpTransport>>,` to `ClientBuilder` (next to `media_fetcher`), initialise it to `None` in `ClientBuilder::new`, and add the setter directly above `pub fn media_fetcher`:

```rust
    /// Route all of the client's HTTP traffic through a custom
    /// [`HttpTransport`](crate::HttpTransport) instead of the built-in client.
    pub fn http_transport(mut self, transport: Arc<dyn crate::HttpTransport>) -> Self {
        self.http_transport = Some(transport);
        self
    }
```

In `build()`, replace `let http_client = HttpClient::new(inner_http_client.clone(), self.request_config);` with:

```rust
        let http_client = HttpClient::new(inner_http_client.clone(), self.request_config)
            .with_transport(self.http_transport.clone());
```

In `client/mod.rs`, add next to `pub fn http_client`:

```rust
    /// Send a raw HTTP request through the client's HTTP stack (including any
    /// custom [`HttpTransport`](crate::HttpTransport)), returning the raw
    /// response. Prefer this over [`Client::http_client`], which bypasses a
    /// custom transport.
    pub async fn send_raw_request(
        &self,
        request: http::Request<bytes::Bytes>,
    ) -> Result<http::Response<bytes::Bytes>, HttpError> {
        let timeout = self.inner.http_client.request_config.timeout;
        self.inner.http_client.execute_raw(request, timeout).await
    }
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `cargo test -p matrix-sdk --lib http_client::transport`
Expected: `test result: ok. 3 passed`.

Then check nothing else regressed and wasm still compiles:

```bash
cargo test -p matrix-sdk --lib http_client 2>&1 | tail -3
cargo check -p matrix-sdk --target wasm32-unknown-unknown --no-default-features --features js,indexeddb,e2e-encryption 2>&1 | tail -2
```

Expected: `test result: ok`, and `Finished` for the wasm check. (If the wasm target is missing: `rustup target add wasm32-unknown-unknown`.)

- [ ] **Step 8: Commit**

```bash
git add crates/matrix-sdk/src
git commit -m "Add a pluggable HttpTransport to the SDK's HTTP client

Clients can now route all requests through a custom transport instead
of reqwest, for platforms such as watchOS where apps may not open their
own sockets. Transport failures are treated as network failures for
retry purposes. reqwest remains the default, so there is no behaviour
change when no transport is set.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

### Task 3: OAuth 2.0 requests through the transport

**Files:**
- Modify: `crates/matrix-sdk/src/authentication/oauth/http_client.rs`
- Modify: `crates/matrix-sdk/src/authentication/oauth/mod.rs` (`OAuth::new`)

**Interfaces:**
- Consumes: `crate::HttpTransport`, `HttpClient::transport` (Task 2).
- Produces: `OAuthHttpClient { inner: ReqwestClient, transport: Option<Arc<dyn HttpTransport>>, … }`. When `transport` is `Some`, every OAuth request (metadata, registration, device authorization, token, revocation) goes through it. The error type stays `HttpClientError<reqwest::Error>`, and transport failures map to `HttpClientError::Other(String)`, so no public OAuth error types change.

- [ ] **Step 1: Write the failing test**

Append to `authentication/oauth/http_client.rs`:

```rust
#[cfg(all(test, not(target_family = "wasm")))]
mod tests {
    use std::{
        sync::{Arc, Mutex},
        time::Duration,
    };

    use bytes::Bytes;
    use matrix_sdk_base::BoxFuture;
    use oauth2::{AsyncHttpClient, HttpClientError};

    use super::OAuthHttpClient;
    use crate::{HttpTransport, TransportError};

    #[tokio::test]
    async fn test_oauth_requests_use_the_transport() {
        let transport = Arc::new(StubTransport::default());
        let client = OAuthHttpClient::new(reqwest::Client::new(), Some(transport.clone()));
        let request = http::Request::post("https://auth.example.org/oauth2/token")
            .header("content-type", "application/x-www-form-urlencoded")
            .body(b"grant_type=x".to_vec())
            .unwrap();

        let response = client.call(request).await.expect("call should succeed");

        assert_eq!(response.status(), 200);
        assert_eq!(response.body(), br#"{"ok":true}"#);
        assert_eq!(transport.seen.lock().unwrap().as_slice(), ["/oauth2/token"]);
    }

    #[tokio::test]
    async fn test_oauth_transport_failures_are_reported() {
        let transport = Arc::new(StubTransport { fail: true, ..Default::default() });
        let client = OAuthHttpClient::new(reqwest::Client::new(), Some(transport));
        let request = http::Request::get("https://auth.example.org/x").body(Vec::new()).unwrap();

        let error = client.call(request).await.expect_err("call should fail");

        assert!(matches!(error, HttpClientError::Other(message) if message.contains("offline")));
    }

    // MARK: - Helpers

    #[derive(Debug, Default)]
    struct StubTransport {
        fail: bool,
        seen: Mutex<Vec<String>>,
    }

    impl HttpTransport for StubTransport {
        fn execute(
            &self,
            request: http::Request<Bytes>,
            _timeout: Option<Duration>,
        ) -> BoxFuture<'static, Result<http::Response<Bytes>, TransportError>> {
            self.seen.lock().unwrap().push(request.uri().path().to_owned());
            let fail = self.fail;
            Box::pin(async move {
                if fail {
                    return Err(TransportError("offline".to_owned()));
                }
                Ok(http::Response::builder()
                    .status(200)
                    .body(Bytes::from_static(br#"{"ok":true}"#))
                    .unwrap())
            })
        }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cargo test -p matrix-sdk --lib oauth::http_client 2>&1 | grep -E "^error" | head -3`
Expected: `no function or associated item named 'new' found for struct 'OAuthHttpClient'`.

- [ ] **Step 3: Implement**

In `oauth/http_client.rs`, extend the struct and add a constructor and transport branch:

```rust
use std::sync::Arc;

use bytes::Bytes;

use crate::HttpTransport;

/// An HTTP client for making OAuth 2.0 requests.
#[derive(Debug, Clone)]
pub(super) struct OAuthHttpClient {
    pub(super) inner: ReqwestClient,
    /// Custom transport that replaces `inner` when set.
    pub(super) transport: Option<Arc<dyn HttpTransport>>,
    /// Rewrite HTTPS requests to use HTTP instead.
    ///
    /// This is a workaround to bypass some checks that require an HTTPS URL,
    /// but we can only mock HTTP URLs.
    #[cfg(test)]
    pub(super) insecure_rewrite_https_to_http: bool,
}

impl OAuthHttpClient {
    pub(super) fn new(inner: reqwest::Client, transport: Option<Arc<dyn HttpTransport>>) -> Self {
        Self {
            inner: ReqwestClient::from(inner),
            transport,
            #[cfg(test)]
            insecure_rewrite_https_to_http: false,
        }
    }
}
```

In `call`, replace `let response = self.inner.call(request).await?;` with:

```rust
            let response = match &self.transport {
                Some(transport) => {
                    let (parts, body) = request.into_parts();
                    let request = http::Request::from_parts(parts, Bytes::from(body));
                    let response = transport
                        .execute(request, None)
                        .await
                        .map_err(|error| HttpClientError::Other(error.to_string()))?;
                    let (parts, body) = response.into_parts();
                    http::Response::from_parts(parts, body.to_vec())
                }
                None => self.inner.call(request).await?,
            };
```

In `oauth/mod.rs`, replace the body of `OAuth::new` with:

```rust
        let http_client = OAuthHttpClient::new(
            client.inner.http_client.inner.clone(),
            client.inner.http_client.transport.clone(),
        );
        Self { client, http_client }
```

Search for any other `OAuthHttpClient {` struct literal (`grep -rn "OAuthHttpClient {" crates/matrix-sdk/src`) and add `transport: None,` to each.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cargo test -p matrix-sdk --lib oauth 2>&1 | tail -3`
Expected: `test result: ok.` (the new tests plus the existing OAuth tests).

- [ ] **Step 5: Commit**

```bash
git add crates/matrix-sdk/src/authentication/oauth
git commit -m "Send OAuth 2.0 requests through the custom HTTP transport

OAuth metadata, registration, device authorization and token requests
now honour a client's HttpTransport. Transport failures surface as
HttpClientError::Other, keeping the public OAuth error types unchanged.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

### Task 4: QR-login rendezvous channel through the transport

**Files:**
- Modify: `crates/matrix-sdk/src/authentication/oauth/qrcode/rendezvous_channel/msc_4108.rs`
- Modify: `crates/matrix-sdk/src/authentication/oauth/qrcode/secure_channel/mod.rs`
- Modify: `crates/matrix-sdk/src/authentication/oauth/qrcode/login.rs`, `…/qrcode/grant.rs` (callers)

**Interfaces:**
- Consumes: `HttpClient::execute_raw` (Task 2).
- Produces: `EstablishedSecureChannel::from_qr_code(client: HttpClient, qr_code_data: &QrCodeData, expected_mode: QrCodeIntent)` (was `reqwest::Client`); `RendezvousChannel::receive_message_impl(client: &HttpClient, …)`. There are no public API changes.

- [ ] **Step 1: Write the failing test**

Append to the existing `#[cfg(all(test, not(target_family = "wasm")))] mod test` in `msc_4108.rs` (reuse its imports; add the ones shown):

```rust
    #[async_test]
    async fn test_rendezvous_uses_custom_transport() {
        use std::sync::{Arc, Mutex};

        use crate::{HttpTransport, TransportError, config::RequestConfig, http_client::HttpClient};

        #[derive(Debug, Default)]
        struct Recorder(Mutex<Vec<String>>);

        impl HttpTransport for Recorder {
            fn execute(
                &self,
                request: http::Request<bytes::Bytes>,
                _timeout: Option<std::time::Duration>,
            ) -> matrix_sdk_base::BoxFuture<'static, Result<http::Response<bytes::Bytes>, TransportError>>
            {
                self.0.lock().unwrap().push(format!("{} {}", request.method(), request.uri().path()));
                Box::pin(async move {
                    Ok(http::Response::builder()
                        .status(200)
                        .header("etag", "1")
                        .header("expires", "Wed, 07 Sep 2033 12:00:00 GMT")
                        .header("last-modified", "Wed, 07 Sep 2033 12:00:00 GMT")
                        .header("content-type", "text/plain")
                        .body(bytes::Bytes::new())
                        .unwrap())
                })
            }
        }

        let recorder = Arc::new(Recorder::default());
        let client = HttpClient::new(reqwest::Client::new(), RequestConfig::new().disable_retry())
            .with_transport(Some(recorder.clone()));
        let url = Url::parse("https://rendezvous.example.org/abc").unwrap();

        RendezvousChannel::create_inbound(client, &url).await.expect("inbound channel");

        assert_eq!(recorder.0.lock().unwrap().as_slice(), ["GET /abc"]);
    }
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cargo test -p matrix-sdk --lib test_rendezvous_uses_custom_transport 2>&1 | tail -5`
Expected: FAIL. The request goes through reqwest instead of the recorder (connection error to `rendezvous.example.org`, or an assertion failure with an empty vec).

- [ ] **Step 3: Implement**

In `msc_4108.rs`:

1. Change `receive_message_impl` to take `client: &HttpClient` and build the request with `http`:

```rust
    #[instrument(skip(client))]
    async fn receive_message_impl(
        client: &HttpClient,
        etag: Option<String>,
        rendezvous_url: &Url,
    ) -> Result<RendezvousGetResponse, HttpError> {
        let mut builder = http::Request::builder().method(Method::GET).uri(rendezvous_url.as_str());

        if let Some(etag) = etag {
            builder = builder.header(IF_NONE_MATCH, etag);
        }

        let request = builder.body(Bytes::new()).expect("rendezvous GET request is valid");
        let response = client.execute_raw(request, None).await?;

        debug!("Received data from the rendezvous channel {response:?}");

        let status_code = response.status();

        if status_code.is_client_error() {
            return Err(response_to_error(status_code, response.body()));
        }

        let headers = response.headers();
        let etag = get_header(headers, &ETAG)?;
        let expires = get_header(headers, &EXPIRES)?;
        let last_modified = get_header(headers, &LAST_MODIFIED)?;
        #[allow(clippy::result_large_err)]
        let content_type = headers
            .get(CONTENT_TYPE)
            .map(|c| c.to_str().map_err(FromHttpResponseError::<RumaApiError>::from))
            .transpose()?
            .map(ToOwned::to_owned);

        let body = response.body().to_vec();

        Ok(RendezvousGetResponse { status_code, etag, expires, last_modified, content_type, body })
    }
```

2. Update its two call sites from `&client.inner` / `&self.client.inner` to `&client` / `&self.client`.
3. Rewrite the body of `send` to use `execute_raw`:

```rust
    #[instrument(skip_all)]
    pub(super) async fn send(&mut self, message: Vec<u8>) -> Result<(), HttpError> {
        let request = http::Request::builder()
            .method(Method::PUT)
            .uri(self.rendezvous_url().as_str())
            .header(IF_MATCH, self.etag.clone())
            .header(CONTENT_TYPE, TEXT_PLAIN_CONTENT_TYPE)
            .body(Bytes::from(message))
            .expect("rendezvous PUT request is valid");

        debug!("Sending a request to the rendezvous channel");

        let response = self.client.execute_raw(request, None).await?;
        let status = response.status();

        debug!("Response for the rendezvous sending request {response:?}");

        if status.is_success() {
            // We successfully sent a message, update our copy of the ETAG.
            self.etag = get_header(response.headers(), &ETAG)?;
            Ok(())
        } else {
            Err(response_to_error(status, response.body()))
        }
    }
```

Add `use bytes::Bytes;` if not already imported. If `response_to_error` takes `&Bytes`/`&[u8]`, pass `response.body()` (`&Bytes` derefs to `&[u8]`); adjust the call to `response.body().as_ref()` if the compiler asks.

In `secure_channel/mod.rs`, change `from_qr_code`'s first parameter to `client: HttpClient` and delete the line `let client = HttpClient::new(client, RequestConfig::short_retry());`. In the tests at the bottom of the same file, replace `reqwest::Client::new()` arguments to `from_qr_code` with `HttpClient::new(reqwest::Client::new(), RequestConfig::short_retry())`.

In `login.rs` (the `scan` path, around `let http_client = self.client.inner.http_client.inner.clone();`) and `grant.rs` (the `from_qr_code(self.client.inner.http_client.inner.clone(), …)` call), pass `self.client.inner.http_client.clone()` instead. In both files' test modules, wrap every `reqwest::Client::new()` passed to `from_qr_code` as `HttpClient::new(reqwest::Client::new(), Default::default())`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cargo test -p matrix-sdk --lib qrcode 2>&1 | tail -3`
Expected: `test result: ok.` (new test plus the existing QR login, grant and secure-channel tests).

- [ ] **Step 5: Audit for remaining bypasses**

```bash
grep -rn "reqwest::" crates/matrix-sdk/src --include='*.rs' \
  | grep -v -E "http_client/(mod|native|wasm)\.rs|error\.rs|lib\.rs|local_server\.rs|oauth/(error|http_client)\.rs|client/builder/mod\.rs|client/mod\.rs:.*fn http_client" \
  | grep -v -E "#\[cfg\(test\)\]|mod tests|HttpClient::new\(reqwest::Client::new\(\)"
```

Expected: no output (only test-only constructions and the transport-aware core remain). Any other hit is a bypass: route it through `execute_raw` in the same way before committing.

- [ ] **Step 6: Commit**

```bash
git add crates/matrix-sdk/src/authentication/oauth/qrcode
git commit -m "Route the QR login rendezvous channel through the HTTP transport

The MSC4108 rendezvous GET/PUT requests and the secure channel set-up
now use HttpClient::execute_raw, so QR login works on platforms where
the SDK must not open sockets itself.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

### Task 5: FFI `HttpTransport` foreign trait and `ClientBuilder.httpTransport`

**Files:**
- Create: `bindings/matrix-sdk-ffi/src/http_transport.rs`
- Modify: `bindings/matrix-sdk-ffi/src/lib.rs` (`mod http_transport;`)
- Modify: `bindings/matrix-sdk-ffi/src/client_builder.rs` (field + setter + wiring)
- Modify: `bindings/matrix-sdk-ffi/src/client.rs` (`get_url` via `send_raw_request`)

**Interfaces:**
- Consumes: `matrix_sdk::{HttpTransport, TransportError}`, `ClientBuilder::http_transport`, `Client::send_raw_request` (Task 2).
- Produces (Swift, via uniffi):
  ```swift
  public protocol HttpTransport: AnyObject, Sendable {
      func execute(request: HttpTransportRequest) async throws -> HttpTransportResponse
  }
  public struct HttpHeader { public var name: String; public var value: String }
  public struct HttpTransportRequest { method: String; url: String; headers: [HttpHeader]; body: Data; timeoutMs: UInt64? }
  public struct HttpTransportResponse { status: UInt16; headers: [HttpHeader]; body: Data }
  public enum HttpTransportError: Error { case Network(message: String) }
  ClientBuilder.httpTransport(transport: HttpTransport) -> ClientBuilder
  ```

- [ ] **Step 1: Write the failing test**

Create `bindings/matrix-sdk-ffi/src/http_transport.rs` containing only:

```rust
#[cfg(test)]
mod tests {
    use std::sync::{Arc, Mutex};

    use matrix_sdk::bytes::Bytes;
    use matrix_sdk_base::http;

    use super::{HttpHeader, HttpTransport, HttpTransportError, HttpTransportRequest, HttpTransportResponse, HttpTransportWrap};

    #[tokio::test]
    async fn test_wrap_converts_requests_and_responses() {
        let foreign = Arc::new(EchoTransport::default());
        let wrap = HttpTransportWrap(foreign.clone());
        let request = http::Request::post("https://example.org/_matrix/x?y=1")
            .header("authorization", "Bearer t")
            .body(Bytes::from_static(b"hello"))
            .unwrap();

        let response = matrix_sdk::HttpTransport::execute(&wrap, request, Some(std::time::Duration::from_millis(1500)))
            .await
            .expect("execute");

        let seen = foreign.seen.lock().unwrap().take().expect("request seen");
        assert_eq!(seen.method, "POST");
        assert_eq!(seen.url, "https://example.org/_matrix/x?y=1");
        assert_eq!(seen.body, b"hello");
        assert_eq!(seen.timeout_ms, Some(1500));
        assert!(seen.headers.iter().any(|h| h.name == "authorization" && h.value == "Bearer t"));
        assert_eq!(response.status(), 201);
        assert_eq!(response.headers()["etag"], "abc");
        assert_eq!(response.body().as_ref(), b"world");
    }

    #[tokio::test]
    async fn test_wrap_maps_foreign_errors() {
        let wrap = HttpTransportWrap(Arc::new(EchoTransport { fail: true, ..Default::default() }));
        let request = http::Request::get("https://example.org").body(Bytes::new()).unwrap();

        let error = matrix_sdk::HttpTransport::execute(&wrap, request, None).await.expect_err("should fail");

        assert!(error.to_string().contains("no network"));
    }

    // MARK: - Helpers

    #[derive(Default)]
    struct EchoTransport {
        fail: bool,
        seen: Mutex<Option<HttpTransportRequest>>,
    }

    #[async_trait::async_trait]
    impl HttpTransport for EchoTransport {
        async fn execute(&self, request: HttpTransportRequest) -> Result<HttpTransportResponse, HttpTransportError> {
            *self.seen.lock().unwrap() = Some(request);
            if self.fail {
                return Err(HttpTransportError::Network { msg: "no network".to_owned() });
            }
            Ok(HttpTransportResponse {
                status: 201,
                headers: vec![HttpHeader { name: "etag".to_owned(), value: "abc".to_owned() }],
                body: b"world".to_vec(),
            })
        }
    }
}
```

Add `mod http_transport;` to `bindings/matrix-sdk-ffi/src/lib.rs` (alphabetically, after `mod helpers;`).

- [ ] **Step 2: Run the test to verify it fails**

Run: `cargo test -p matrix-sdk-ffi --lib http_transport 2>&1 | grep -E "^error" | head -3`
Expected: `unresolved imports super::HttpHeader …`.

- [ ] **Step 3: Implement the FFI types and wrapper**

Prepend to `http_transport.rs`:

```rust
//! Lets the host app perform the SDK's HTTP requests (e.g. through
//! `URLSession` on watchOS, where the SDK may not open sockets itself).

use std::{fmt::Debug, sync::Arc, time::Duration};

use futures_util::future::BoxFuture;
use matrix_sdk::bytes::Bytes;
use matrix_sdk_base::http;
use matrix_sdk_common::{SendOutsideWasm, SyncOutsideWasm};

#[derive(uniffi::Record)]
pub struct HttpHeader {
    pub name: String,
    pub value: String,
}

#[derive(uniffi::Record)]
pub struct HttpTransportRequest {
    pub method: String,
    pub url: String,
    pub headers: Vec<HttpHeader>,
    pub body: Vec<u8>,
    /// The SDK's timeout for this request, in milliseconds.
    pub timeout_ms: Option<u64>,
}

#[derive(uniffi::Record)]
pub struct HttpTransportResponse {
    pub status: u16,
    pub headers: Vec<HttpHeader>,
    pub body: Vec<u8>,
}

#[derive(Debug, thiserror::Error, uniffi::Error)]
#[uniffi(flat_error)]
pub enum HttpTransportError {
    #[error("{msg}")]
    Network { msg: String },
}

/// Performs HTTP requests on behalf of the SDK.
#[matrix_sdk_ffi_macros::export(callback_interface)]
#[async_trait::async_trait]
pub trait HttpTransport: SendOutsideWasm + SyncOutsideWasm {
    async fn execute(
        &self,
        request: HttpTransportRequest,
    ) -> Result<HttpTransportResponse, HttpTransportError>;
}

pub(crate) struct HttpTransportWrap(pub(crate) Arc<dyn HttpTransport>);

impl Debug for HttpTransportWrap {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("HttpTransportWrap")
    }
}

impl matrix_sdk::HttpTransport for HttpTransportWrap {
    fn execute(
        &self,
        request: http::Request<Bytes>,
        timeout: Option<Duration>,
    ) -> BoxFuture<'static, Result<http::Response<Bytes>, matrix_sdk::TransportError>> {
        let transport = self.0.clone();
        Box::pin(async move {
            let (parts, body) = request.into_parts();
            let request = HttpTransportRequest {
                method: parts.method.to_string(),
                url: parts.uri.to_string(),
                headers: parts
                    .headers
                    .iter()
                    .filter_map(|(name, value)| {
                        Some(HttpHeader { name: name.to_string(), value: value.to_str().ok()?.to_owned() })
                    })
                    .collect(),
                body: body.to_vec(),
                timeout_ms: timeout.map(|t| t.as_millis().try_into().unwrap_or(u64::MAX)),
            };

            let response =
                transport.execute(request).await.map_err(|e| matrix_sdk::TransportError(e.to_string()))?;

            let mut builder = http::Response::builder().status(response.status);
            for header in response.headers {
                builder = builder.header(header.name, header.value);
            }
            builder.body(Bytes::from(response.body)).map_err(|e| matrix_sdk::TransportError(e.to_string()))
        })
    }
}
```

- [ ] **Step 4: Wire it into the FFI `ClientBuilder`**

In `client_builder.rs`, add a field to the `ClientBuilder` struct after `media_fetcher`:

```rust
    http_transport: Option<Arc<dyn crate::http_transport::HttpTransport>>,
```

initialise it to `None` in `ClientBuilder::new` (next to `media_fetcher: None,`), and add this exported method to the `#[matrix_sdk_ffi_macros::export] impl ClientBuilder` block (next to `dm_room_definition`):

```rust
    /// Perform all HTTP requests through the given transport instead of the
    /// SDK's built-in HTTP client.
    pub fn http_transport(
        self: Arc<Self>,
        transport: Box<dyn crate::http_transport::HttpTransport>,
    ) -> Arc<Self> {
        let mut builder = unwrap_or_clone_arc(self);
        builder.http_transport = Some(transport.into());
        Arc::new(builder)
    }
```

In `build()`, directly before `if let Some(media_fetcher) = builder.media_fetcher {`:

```rust
        if let Some(transport) = builder.http_transport {
            inner_builder = inner_builder
                .http_transport(Arc::new(crate::http_transport::HttpTransportWrap(transport)));
        }
```

- [ ] **Step 5: Make `Client.getUrl` honour the transport**

In `bindings/matrix-sdk-ffi/src/client.rs`, replace the body of `get_url`:

```rust
    pub async fn get_url(&self, url: String) -> Result<Vec<u8>, ClientError> {
        let request = matrix_sdk_base::http::Request::get(url)
            .body(matrix_sdk::bytes::Bytes::new())
            .map_err(|e| ClientError::from_str(e, None))?;
        let response = self.inner.send_raw_request(request).await?;
        if response.status().is_success() {
            Ok(response.into_body().to_vec())
        } else {
            Err(ClientError::Generic {
                msg: response.status().to_string(),
                details: String::from_utf8(response.body().to_vec()).ok(),
            })
        }
    }
```

If `?` on `send_raw_request` doesn't compile because `ClientError: From<HttpError>` is missing, use `.map_err(ClientError::from_err)?`.

- [ ] **Step 6: Run the tests to verify they pass, and rebuild for the watch**

```bash
cargo test -p matrix-sdk-ffi --lib http_transport 2>&1 | tail -3
export PATH=$HOME/.cargo/bin:/opt/homebrew/bin:$PATH DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
AWS_LC_SYS_NO_ASM=1 cargo +nightly build -Zbuild-std -p matrix-sdk-ffi --target aarch64-apple-watchos-sim --lib 2>&1 | tail -1
```

Expected: `test result: ok. 2 passed`, then `Finished`.

Then run the full `matrix-sdk` unit test suite to confirm that the default reqwest path is unchanged for iOS:

```bash
cargo test -p matrix-sdk --lib 2>&1 | tail -3
```

Expected: `test result: ok.` with 0 failures.

- [ ] **Step 7: Commit**

```bash
git add bindings/matrix-sdk-ffi/src
git commit -m "Expose the HTTP transport to FFI consumers

Adds an HttpTransport callback interface and ClientBuilder.httpTransport
so apps can execute the SDK's requests with a platform HTTP stack (for
example URLSession on watchOS). Client.getUrl now honours the transport.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

## Phase B — Watch repo foundations (`~/Developer/git/github.com/element-hq/element-x-watchos`)

### Task 6: Repo scaffolding, SDK package, Compound tokens, app shell

**Files:**
- Create: `.gitignore`, `LICENSE` (copied from `../element-x-ios/LICENSE`), `CLAUDE.md`, `AGENTS.md`, `SHARED_FROM_IOS.md`
- Create: `Tools/build-sdk.sh`
- Create: `Packages/MatrixRustSDK/Package.swift` (+ generated `Sources/MatrixRustSDK/*.swift` and `MatrixSDKFFI.xcframework`, both git-ignored)
- Create: `Packages/CompoundDesignTokens/Package.swift`, `Packages/CompoundDesignTokens/Sources/CompoundDesignTokens/…` (vendored)
- Create: `project.yml`, `Config/Local.xcconfig.example`, `ElementXWatch/SupportingFiles/ElementXWatch.entitlements`
- Create: `ElementXWatch/Sources/Application/ElementXWatchApp.swift`, `ElementXWatch/Resources/Assets.xcassets/{Contents.json,AppIcon.appiconset/Contents.json,AccentColor.colorset/Contents.json}`
- Test: `UnitTests/Sources/SmokeTests.swift`

**Interfaces:**
- Produces: module `MatrixRustSDK` (same name as `matrix-rust-components-swift`), module `CompoundDesignTokens` (`CompoundColorTokens`, `CompoundCoreColorTokens`, `CompoundIcons`, `CompoundDesignTokens`), Xcode scheme `ElementXWatch` with `UnitTests`.
- Produces: `Tools/build-sdk.sh [--dev]`: `--dev` builds only `aarch64-apple-watchos-sim` with the `dev` profile. Without the flag it builds all three targets with `reldbg`.

- [ ] **Step 1: Install tools (skip if present)**

```bash
brew list sourcery >/dev/null 2>&1 || brew install sourcery
brew list xcodegen >/dev/null 2>&1 || brew install xcodegen
```

- [ ] **Step 2: Repo hygiene files**

`.gitignore`:

```gitignore
.DS_Store
.idea/
xcuserdata/
DerivedData/
build/
*.xcodeproj
Config/Local.xcconfig
Packages/MatrixRustSDK/MatrixSDKFFI.xcframework/
Packages/MatrixRustSDK/Sources/
.build/
.swiftpm/
```

Copy the licence: `cp ../element-x-ios/LICENSE LICENSE`.

`CLAUDE.md`:

```markdown
@AGENTS.md
```

`AGENTS.md`:

```markdown
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
```

`SHARED_FROM_IOS.md`:

```markdown
# Files derived from element-x-ios

Source commit: `ad1d7a301` (element-x-ios `develop`, 2026-09-25). Licence: AGPL-3.0-only OR LicenseRef-Element-Commercial.

| Watch file | Source | Changes |
|---|---|---|
| `Packages/CompoundDesignTokens/Sources/CompoundDesignTokens/*` | compound-design-tokens `v11.0.0` `assets/ios/swift` | Dropped `CompoundCoreUIColorTokens.swift`, `CompoundUIColorTokens.swift` (UIKit-only) and `Resources/theme.iife.js`. |
| `Tools/Sourcery/AutoMockable.stencil` | `Tools/Sourcery/AutoMockable.stencil` | Removed iOS-only imports. |
```

- [ ] **Step 3: SDK build script**

`Tools/build-sdk.sh` (make it executable with `chmod +x`):

```bash
#!/usr/bin/env bash
# Builds the matrix-rust-sdk fork for watchOS into Packages/MatrixRustSDK.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${MATRIX_RUST_SDK_PATH:-$ROOT/../matrix-rust-sdk}"
PACKAGE="$ROOT/Packages/MatrixRustSDK"

export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:$PATH"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
# aws-lc's assembly mixes 64-bit limbs with arm64_32's 32-bit words; it is only used by reqwest's TLS,
# which the watch never uses (all traffic goes through URLSession).
export AWS_LC_SYS_NO_ASM=1

if [[ "${1:-}" == "--dev" ]]; then
  PROFILE=dev
  TARGETS=(--target aarch64-apple-watchos-sim)
else
  PROFILE=reldbg
  TARGETS=(--target aarch64-apple-watchos-sim --target aarch64-apple-watchos --target arm64_32-apple-watchos)
fi

cd "$SDK"
echo "Building $(git rev-parse --short HEAD) ($(git branch --show-current)) with profile $PROFILE"
# --features "" drops Sentry, which would open its own sockets.
cargo xtask swift build-framework \
  --profile "$PROFILE" \
  "${TARGETS[@]}" \
  --features "" \
  --watchos-deployment-target 11.0 \
  --sequentially \
  --components-path "$PACKAGE"

echo "SDK ready in $PACKAGE"
```

- [ ] **Step 4: Local SDK package**

`Packages/MatrixRustSDK/Package.swift`:

```swift
// swift-tools-version:5.9
// Mirrors matrix-rust-components-swift so app code can `import MatrixRustSDK` unchanged.
// The generated bindings require the Swift 5 language mode.
import PackageDescription

let package = Package(
    name: "MatrixRustSDK",
    platforms: [.watchOS(.v11)],
    products: [
        .library(name: "MatrixRustSDK", targets: ["MatrixRustSDK"])
    ],
    targets: [
        .binaryTarget(name: "MatrixSDKFFI", path: "MatrixSDKFFI.xcframework"),
        .target(name: "MatrixRustSDK",
                dependencies: ["MatrixSDKFFI"],
                path: "Sources/MatrixRustSDK",
                linkerSettings: [.linkedLibrary("c++")])
    ]
)
```

Build the SDK into it:

```bash
Tools/build-sdk.sh --dev
ls Packages/MatrixRustSDK/Sources/MatrixRustSDK | head -3 && ls Packages/MatrixRustSDK/MatrixSDKFFI.xcframework
```

Expected: `matrix_sdk.swift`, `matrix_sdk_base.swift` and so on, then `Info.plist` and `watchos-arm64-simulator`.

- [ ] **Step 5: Vendored Compound design tokens**

```bash
TMP=$(mktemp -d)
git clone -q --depth 1 --branch v11.0.0 https://github.com/element-hq/compound-design-tokens "$TMP/tokens"
DEST=Packages/CompoundDesignTokens/Sources/CompoundDesignTokens
mkdir -p "$DEST"
cp -R "$TMP/tokens/assets/ios/swift/"* "$DEST/"
rm -f "$DEST/CompoundCoreUIColorTokens.swift" "$DEST/CompoundUIColorTokens.swift"
rm -rf "$DEST/Resources"
ls "$DEST"
```

Expected: `Colors.xcassets CompoundColorTokens.swift CompoundCoreColorTokens.swift CompoundDesignTokens+Bundle.swift CompoundDesignTokens.swift CompoundIcons.swift Icons.xcassets`.

`Packages/CompoundDesignTokens/Package.swift`:

```swift
// swift-tools-version: 6.0
// Vendored from compound-design-tokens v11.0.0 without the UIKit-only colour files.
import PackageDescription

let package = Package(
    name: "CompoundDesignTokens",
    platforms: [.watchOS(.v11)],
    products: [
        .library(name: "CompoundDesignTokens", targets: ["CompoundDesignTokens"])
    ],
    targets: [
        .target(name: "CompoundDesignTokens",
                resources: [.process("Colors.xcassets"), .process("Icons.xcassets")])
    ]
)
```

- [ ] **Step 6: XcodeGen project**

`project.yml`:

```yaml
name: ElementXWatch
options:
  bundleIdPrefix: io.ilie
  deploymentTarget:
    watchOS: "11.0"
  createIntermediateGroups: true
configFiles:
  Debug: Config/Base.xcconfig
  Release: Config/Base.xcconfig
settings:
  base:
    SWIFT_VERSION: 6.2
    SWIFT_APPROACHABLE_CONCURRENCY: YES
    SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor
    CODE_SIGN_STYLE: Automatic
    ENABLE_USER_SCRIPT_SANDBOXING: NO
packages:
  MatrixRustSDK:
    path: Packages/MatrixRustSDK
  CompoundDesignTokens:
    path: Packages/CompoundDesignTokens
  QRCodeGenerator:
    url: https://github.com/fwcd/swift-qrcode-generator
    exactVersion: 2.0.2
targets:
  ElementXWatch:
    type: application
    platform: watchOS
    sources:
      - ElementXWatch/Sources
      - ElementXWatch/Resources
    dependencies:
      - package: MatrixRustSDK
      - package: CompoundDesignTokens
      - package: QRCodeGenerator
    entitlements:
      path: ElementXWatch/SupportingFiles/ElementXWatch.entitlements
    info:
      path: ElementXWatch/SupportingFiles/Info.plist
      properties:
        CFBundleDisplayName: Element X
        CFBundleShortVersionString: "0.1.0"
        CFBundleVersion: "1"
        WKApplication: true
        WKWatchOnly: true
        UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: io.ilie.elementx.watch
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        OTHER_LDFLAGS: ["-ObjC"]
    preBuildScripts:
      - name: Sourcery
        basedOnDependencyAnalysis: false
        script: |
          export PATH="/opt/homebrew/bin:$PATH"
          if which sourcery >/dev/null; then
            sourcery --config Tools/Sourcery/AutoMockableConfig.yml
          else
            echo "warning: sourcery not installed"
          fi
  UnitTests:
    type: bundle.unit-test
    platform: watchOS
    sources:
      - UnitTests/Sources
    dependencies:
      - target: ElementXWatch
      - package: MatrixRustSDK
      - package: CompoundDesignTokens
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: io.ilie.elementx.watch.unittests
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/ElementXWatch.app/ElementXWatch"
        BUNDLE_LOADER: "$(TEST_HOST)"
        GENERATE_INFOPLIST_FILE: YES
schemes:
  ElementXWatch:
    build:
      targets:
        ElementXWatch: all
        UnitTests: [test]
    test:
      targets: [UnitTests]
      gatherCoverageData: true
```

`Config/Base.xcconfig`:

```
// Simulator builds are signed to run locally; device builds need a team in Local.xcconfig.
CODE_SIGN_IDENTITY[sdk=watchsimulator*] = -
#include? "Local.xcconfig"
```

`Config/Local.xcconfig.example`:

```
// Copy to Config/Local.xcconfig (git-ignored) and set your Apple ID team for device builds.
DEVELOPMENT_TEAM = YOURTEAMID
```

`ElementXWatch/SupportingFiles/ElementXWatch.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)io.ilie.elementx.watch</string>
    </array>
</dict>
</plist>
```

Asset catalog, `ElementXWatch/Resources/Assets.xcassets/Contents.json`:

```json
{ "info" : { "author" : "xcode", "version" : 1 } }
```

`ElementXWatch/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [ { "idiom" : "universal", "platform" : "watchos", "size" : "1024x1024" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`ElementXWatch/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`:

```json
{
  "colors" : [ { "color" : { "color-space" : "srgb", "components" : { "red" : "0.051", "green" : "0.741", "blue" : "0.545", "alpha" : "1.000" } }, "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

Temporary app shell, `ElementXWatch/Sources/Application/ElementXWatchApp.swift` (replaced in Task 18):

```swift
//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

@main
struct ElementXWatchApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Element X")
        }
    }
}
```

Sourcery config needs a source to scan even before any protocol exists. Create `Tools/Sourcery/AutoMockableConfig.yml` and the stencil now:

```yaml
sources:
  include:
    - ../../ElementXWatch/Sources
  exclude:
    - ../../ElementXWatch/Sources/Mocks
templates:
  - AutoMockable.stencil
output:
  ../../ElementXWatch/Sources/Mocks/Generated/GeneratedMocks.swift
```

```bash
cp ../element-x-ios/Tools/Sourcery/AutoMockable.stencil Tools/Sourcery/AutoMockable.stencil
# Drop iOS-only imports the watch doesn't have.
sed -i '' -e '/^import AnalyticsEvents$/d' -e '/^import AVFoundation$/d' -e '/^import CallKit$/d' \
  -e '/^import ElementCall$/d' -e '/^import LocalAuthentication$/d' -e '/^import Photos$/d' Tools/Sourcery/AutoMockable.stencil
head -8 Tools/Sourcery/AutoMockable.stencil
mkdir -p ElementXWatch/Sources/Mocks/Generated
```

Expected: the header only imports `Combine`, `SwiftUI`, `MatrixRustSDK` and `Foundation`.

- [ ] **Step 7: Write the smoke test**

`UnitTests/Sources/SmokeTests.swift`:

```swift
import CompoundDesignTokens
@testable import ElementXWatch
import MatrixRustSDK
import SwiftUI
import Testing

struct SmokeTests {
    @Test
    func sdkIsLinked() {
        #expect(!sdkGitSha().isEmpty)
    }

    @Test
    func compoundTokensAreAvailable() {
        _ = CompoundColorTokens().textPrimary
        _ = CompoundIcons().send
    }
}
```

- [ ] **Step 8: Generate, build and test**

```bash
xcodegen
xcodebuild test -project ElementXWatch.xcodeproj -scheme ElementXWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' 2>&1 | tail -15
```

Expected: `** TEST SUCCEEDED **` with 2 tests passed. If the simulator name isn't available, list them with `xcrun simctl list devices available | grep Watch` and use one.

- [ ] **Step 9: Commit**

```bash
git add .gitignore LICENSE CLAUDE.md AGENTS.md SHARED_FROM_IOS.md Tools Packages/MatrixRustSDK/Package.swift Packages/CompoundDesignTokens project.yml Config/Base.xcconfig Config/Local.xcconfig.example ElementXWatch UnitTests
git commit -m "Scaffold the watchOS app with the local SDK and Compound token packages

Adds the XcodeGen project, a build script that compiles the SDK fork
into a local MatrixRustSDK package, vendored Compound design tokens
without their UIKit-only files, Sourcery mock generation and a smoke
test that links both packages.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

### Task 7: Core infrastructure — logging, SDK listeners, list diffs, view-model base

**Files:**
- Create: `ElementXWatch/Sources/Other/MXLog.swift`
- Create: `ElementXWatch/Sources/Other/SDKListener.swift` (derived from iOS `Other/SDKListener.swift`, plus the watch's listener conformances)
- Create: `ElementXWatch/Sources/Other/ListDiff.swift`
- Create: `ElementXWatch/Sources/Other/SwiftUI/BindableState.swift` (copied from iOS)
- Create: `ElementXWatch/Sources/Other/SwiftUI/StateStoreViewModelV2.swift` (derived: no media provider or content scanner)
- Create: `ElementXWatch/Sources/Other/CoordinatorProtocol.swift` (copied from iOS)
- Create: `ElementXWatch/Sources/Other/WatchStrings.swift`
- Create: `ElementXWatch/Sources/Other/Compound+Watch.swift`
- Test: `UnitTests/Sources/ListDiffTests.swift`, `UnitTests/Sources/SDKListenerTests.swift`

**Interfaces:**
- Produces:
  ```swift
  nonisolated enum MXLog { static func verbose/info/warning/error(_ message: @autoclosure () -> String, file: String = #fileID, line: Int = #line) }
  nonisolated final class SDKListener<T>: Sendable { init(_ onUpdate: @escaping @Sendable (T) -> Void); static func onMainActor(_ onUpdate: @escaping @MainActor (T) -> Void) -> SDKListener<T> }
  // Conformances: SyncServiceStateObserver (T == SyncServiceState), RoomListEntriesListener (T == [RoomListEntriesUpdate]),
  // TimelineListener (T == [TimelineDiff]), GeneratedQrLoginProgressListener (T == GeneratedQrLoginProgress),
  // VerificationStateListener (T == VerificationState), RoomListLoadingStateListener (T == RoomListLoadingState),
  // RoomListServiceSyncIndicatorListener (T == RoomListServiceSyncIndicator)
  enum ListDiff<Element> { case append([Element]), clear, pushFront(Element), pushBack(Element), popFront, popBack,
                           insert(index: Int, value: Element), set(index: Int, value: Element), remove(index: Int), truncate(length: Int), reset([Element]) }
  extension ListDiff { init(_ update: RoomListEntriesUpdate, transform: (Room) -> Element); init(_ diff: TimelineDiff, transform: (MatrixRustSDK.TimelineItem) -> Element) }
  extension Array { mutating func apply(_ diff: ListDiff<Element>) }
  class StateStoreViewModelV2<State: BindableState, ViewAction> { var state: State; var context: Context; func process(viewAction:) }
  protocol CoordinatorProtocol: AnyObject { func start(); func stop(); func toPresentable() -> AnyView }
  extension Color { static let compound: CompoundColorTokens }
  extension Image { init(compound keyPath: KeyPath<CompoundIcons, Image>) }
  ```

- [ ] **Step 1: Write the failing tests**

`UnitTests/Sources/ListDiffTests.swift`:

```swift
@testable import ElementXWatch
import Testing

struct ListDiffTests {
    @Test
    func appendAndPushes() {
        var array = [2]
        array.apply(.append([3, 4]))
        array.apply(.pushFront(1))
        array.apply(.pushBack(5))
        #expect(array == [1, 2, 3, 4, 5])
    }

    @Test
    func popsInsertSetRemove() {
        var array = [1, 2, 3, 4]
        array.apply(.popFront)
        array.apply(.popBack)
        array.apply(.insert(index: 1, value: 9))
        array.apply(.set(index: 0, value: 7))
        array.apply(.remove(index: 2))
        #expect(array == [7, 9])
    }

    @Test
    func truncateClearReset() {
        var array = [1, 2, 3]
        array.apply(.truncate(length: 1))
        #expect(array == [1])
        array.apply(.clear)
        #expect(array.isEmpty)
        array.apply(.reset([5, 6]))
        #expect(array == [5, 6])
    }

    @Test
    func outOfRangeDiffsAreIgnoredNotCrashing() {
        var array = [1]
        array.apply(.remove(index: 5))
        array.apply(.set(index: 3, value: 2))
        array.apply(.insert(index: 9, value: 2))
        array.apply(.truncate(length: 10))
        #expect(array == [1, 2])
    }

    @Test
    func popOnEmptyIsIgnored() {
        var array: [Int] = []
        array.apply(.popFront)
        array.apply(.popBack)
        #expect(array.isEmpty)
    }
}
```

(The out-of-range `insert` appends at the end rather than dropping the element: an index past the end is clamped to `count`. That's why the result is `[1, 2]`.)

`UnitTests/Sources/SDKListenerTests.swift`:

```swift
@testable import ElementXWatch
import MatrixRustSDK
import Testing

struct SDKListenerTests {
    @Test
    func mainActorListenerDeliversInOrder() async {
        var received: [SyncServiceState] = []
        let listener = SDKListener<SyncServiceState>.onMainActor { received.append($0) }

        await Task.detached {
            listener.onUpdate(state: .running)
            listener.onUpdate(state: .offline)
            listener.onUpdate(state: .running)
        }.value
        for _ in 0..<50 where received.count < 3 {
            await Task.yield()
        }

        #expect(received == [.running, .offline, .running])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the standard test command with `-only-testing:UnitTests/ListDiffTests -only-testing:UnitTests/SDKListenerTests`.
Expected: build failure: `cannot find 'SDKListener' in scope`, `value of type '[Int]' has no member 'apply'`.

- [ ] **Step 3: Implement**

Every new Swift file starts with the licence header from Task 6's `ElementXWatchApp.swift`. It's omitted below for brevity, but it's required.

`Other/MXLog.swift`:

```swift
import OSLog

/// App-wide logging. Never pass secrets, tokens or message content.
nonisolated enum MXLog {
    private static let logger = Logger(subsystem: "io.ilie.elementx.watch", category: "app")

    static func verbose(_ message: @autoclosure () -> String, file: String = #fileID, line: Int = #line) {
        let text = message()
        logger.debug("[\(file, privacy: .public):\(line, privacy: .public)] \(text, privacy: .public)")
    }

    static func info(_ message: @autoclosure () -> String, file: String = #fileID, line: Int = #line) {
        let text = message()
        logger.info("[\(file, privacy: .public):\(line, privacy: .public)] \(text, privacy: .public)")
    }

    static func warning(_ message: @autoclosure () -> String, file: String = #fileID, line: Int = #line) {
        let text = message()
        logger.warning("[\(file, privacy: .public):\(line, privacy: .public)] \(text, privacy: .public)")
    }

    static func error(_ message: @autoclosure () -> String, file: String = #fileID, line: Int = #line) {
        let text = message()
        logger.error("[\(file, privacy: .public):\(line, privacy: .public)] \(text, privacy: .public)")
    }
}
```

`Other/SDKListener.swift`: copy lines 9–71 of `../element-x-ios/ElementX/Sources/Other/SDKListener.swift` verbatim. That covers `import`s, the `SDKListener` class, the `onMainActor` factory and `StreamContinuationWrapper`. Change `private let onUpdateClosure` to `fileprivate let onUpdateClosure`, then append:

```swift
// MARK: - Conformances used by the watch

nonisolated extension SDKListener: SyncServiceStateObserver where T == SyncServiceState {
    func onUpdate(state: SyncServiceState) { onUpdateClosure(state) }
}

nonisolated extension SDKListener: RoomListEntriesListener where T == [RoomListEntriesUpdate] {
    func onUpdate(roomEntriesUpdate: [RoomListEntriesUpdate]) { onUpdateClosure(roomEntriesUpdate) }
}

nonisolated extension SDKListener: RoomListLoadingStateListener where T == RoomListLoadingState {
    func onUpdate(state: RoomListLoadingState) { onUpdateClosure(state) }
}

nonisolated extension SDKListener: RoomListServiceSyncIndicatorListener where T == RoomListServiceSyncIndicator {
    func onUpdate(syncIndicator: RoomListServiceSyncIndicator) { onUpdateClosure(syncIndicator) }
}

nonisolated extension SDKListener: TimelineListener where T == [TimelineDiff] {
    func onUpdate(diff: [TimelineDiff]) { onUpdateClosure(diff) }
}

nonisolated extension SDKListener: GeneratedQrLoginProgressListener where T == GeneratedQrLoginProgress {
    func onUpdate(state: GeneratedQrLoginProgress) { onUpdateClosure(state) }
}

nonisolated extension SDKListener: VerificationStateListener where T == VerificationState {
    func onUpdate(status: VerificationState) { onUpdateClosure(status) }
}
```

If the compiler reports the same method name used by two conditional conformances (`onUpdate(state:)` appears for both `SyncServiceState` and `RoomListLoadingState`), that's allowed because the `where` clauses differ. If it's rejected, split the second into a tiny `final class RoomListLoadingStateListenerProxy` wrapping a closure instead.

`Other/ListDiff.swift`:

```swift
import MatrixRustSDK

/// A platform-neutral form of the SDK's vector diffs (`RoomListEntriesUpdate`, `TimelineDiff`).
enum ListDiff<Element> {
    case append([Element])
    case clear
    case pushFront(Element)
    case pushBack(Element)
    case popFront
    case popBack
    case insert(index: Int, value: Element)
    case set(index: Int, value: Element)
    case remove(index: Int)
    case truncate(length: Int)
    case reset([Element])
}

extension ListDiff {
    init(_ update: RoomListEntriesUpdate, transform: (Room) -> Element) {
        switch update {
        case .append(let values): self = .append(values.map(transform))
        case .clear: self = .clear
        case .pushFront(let value): self = .pushFront(transform(value))
        case .pushBack(let value): self = .pushBack(transform(value))
        case .popFront: self = .popFront
        case .popBack: self = .popBack
        case .insert(let index, let value): self = .insert(index: Int(index), value: transform(value))
        case .set(let index, let value): self = .set(index: Int(index), value: transform(value))
        case .remove(let index): self = .remove(index: Int(index))
        case .truncate(let length): self = .truncate(length: Int(length))
        case .reset(let values): self = .reset(values.map(transform))
        }
    }

    init(_ diff: TimelineDiff, transform: (MatrixRustSDK.TimelineItem) -> Element) {
        switch diff {
        case .append(let values): self = .append(values.map(transform))
        case .clear: self = .clear
        case .pushFront(let value): self = .pushFront(transform(value))
        case .pushBack(let value): self = .pushBack(transform(value))
        case .popFront: self = .popFront
        case .popBack: self = .popBack
        case .insert(let index, let value): self = .insert(index: Int(index), value: transform(value))
        case .set(let index, let value): self = .set(index: Int(index), value: transform(value))
        case .remove(let index): self = .remove(index: Int(index))
        case .truncate(let length): self = .truncate(length: Int(length))
        case .reset(let values): self = .reset(values.map(transform))
        }
    }
}

extension Array {
    /// Applies a diff defensively: out-of-range indices are logged and ignored rather than crashing.
    mutating func apply(_ diff: ListDiff<Element>) {
        switch diff {
        case .append(let values):
            append(contentsOf: values)
        case .clear:
            removeAll()
        case .pushFront(let value):
            insert(value, at: 0)
        case .pushBack(let value):
            append(value)
        case .popFront:
            if !isEmpty { removeFirst() }
        case .popBack:
            if !isEmpty { removeLast() }
        case .insert(let index, let value):
            insert(value, at: Swift.min(Swift.max(index, 0), count))
        case .set(let index, let value):
            guard indices.contains(index) else { return MXLog.error("ListDiff set out of range: \(index)/\(count)") }
            self[index] = value
        case .remove(let index):
            guard indices.contains(index) else { return MXLog.error("ListDiff remove out of range: \(index)/\(count)") }
            remove(at: index)
        case .truncate(let length):
            if length < count { removeLast(count - length) }
        case .reset(let values):
            self = values
        }
    }
}
```

`Other/SwiftUI/BindableState.swift`: copy iOS `Other/SwiftUI/ViewModel/BindableState.swift` verbatim.

`Other/SwiftUI/StateStoreViewModelV2.swift`: copy iOS `Other/SwiftUI/ViewModel/StateStoreViewModelV2.swift`, then remove the `mediaProvider` and `contentScannerService` parameters, properties and doc comments from both `init`s and `Context`. The result is:

```swift
import Combine
import Foundation
import Observation

/// A common ViewModel implementation for handling of `State` and `ViewAction`s using Swift Observation.
class StateStoreViewModelV2<State: BindableState, ViewAction> {
    /// For storing subscription references.
    var cancellables = Set<AnyCancellable>()

    /// Constrained interface for passing to Views.
    var context: Context

    var state: State {
        get { context.viewState }
        set { context.viewState = newValue }
    }

    init(initialViewState: State) {
        context = Context(initialViewState: initialViewState)
        context.viewModel = self
    }

    /// Override to handle incoming `ViewAction`s from the view.
    func process(viewAction: ViewAction) { }

    // MARK: - Context

    /// The view's interface to the view model: read state, send actions, bind to `bindings`.
    @dynamicMemberLookup
    @Observable final class Context {
        fileprivate weak var viewModel: StateStoreViewModelV2?

        fileprivate(set) var viewState: State

        subscript<T>(dynamicMember keyPath: WritableKeyPath<State.BindStateType, T>) -> T {
            get { viewState.bindings[keyPath: keyPath] }
            set { viewState.bindings[keyPath: keyPath] = newValue }
        }

        func send(viewAction: ViewAction) {
            viewModel?.process(viewAction: viewAction)
        }

        fileprivate init(initialViewState: State) {
            viewState = initialViewState
        }
    }
}
```

`Other/CoordinatorProtocol.swift`: copy iOS `CoordinatorProtocol.swift` verbatim (the protocol plus its default extension).

`Other/WatchStrings.swift` (later tasks add cases here):

```swift
/// English UI strings for the watch app (no localisation yet).
enum WatchStrings {
    static let appName = "Element X"
    static let tryAgain = "Try again"
    static let cancel = "Cancel"
}
```

`Other/Compound+Watch.swift`:

```swift
import CompoundDesignTokens
import SwiftUI

extension Color {
    /// Compound semantic colour tokens, e.g. `Color.compound.textPrimary`.
    static let compound = CompoundColorTokens()
}

extension Image {
    /// A Compound icon, e.g. `Image(compound: \.send)`.
    init(compound keyPath: KeyPath<CompoundIcons, Image>) {
        self = Self.compoundIcons[keyPath: keyPath]
    }

    private static let compoundIcons = CompoundIcons()
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodegen` and then the standard test command (all suites).
Expected: `** TEST SUCCEEDED **`, with ListDiffTests (5), SDKListenerTests (1) and SmokeTests (2) all passing.

- [ ] **Step 5: Record provenance and commit**

Append to the table in `SHARED_FROM_IOS.md`:

```markdown
| `ElementXWatch/Sources/Other/SDKListener.swift` | `ElementX/Sources/Other/SDKListener.swift` | `onUpdateClosure` made `fileprivate`; watch listener conformances added in the same file. |
| `ElementXWatch/Sources/Other/SwiftUI/BindableState.swift` | `ElementX/Sources/Other/SwiftUI/ViewModel/BindableState.swift` | None. |
| `ElementXWatch/Sources/Other/SwiftUI/StateStoreViewModelV2.swift` | `ElementX/Sources/Other/SwiftUI/ViewModel/StateStoreViewModelV2.swift` | Removed media provider and content scanner. |
| `ElementXWatch/Sources/Other/CoordinatorProtocol.swift` | `ElementX/Sources/.../CoordinatorProtocol.swift` | None. |
```

```bash
git add ElementXWatch UnitTests SHARED_FROM_IOS.md
git commit -m "Add logging, SDK listener, list diff and view model foundations

Brings over the iOS SDKListener and StateStoreViewModelV2 patterns, adds
a defensive ListDiff for the SDK's room list and timeline vector diffs,
and Compound token accessors for SwiftUI.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

### Task 8: `URLSessionTransport`

**Files:**
- Create: `ElementXWatch/Sources/Services/Transport/URLSessionTransport.swift`
- Test: `UnitTests/Sources/URLSessionTransportTests.swift`, `UnitTests/Sources/Support/StubURLProtocol.swift`

**Interfaces:**
- Consumes: `MatrixRustSDK.HttpTransport`, `HttpTransportRequest`, `HttpTransportResponse`, `HttpHeader`, `HttpTransportError.Network(message:)` (Task 5); `MXLog` (Task 7).
- Produces:
  ```swift
  nonisolated final class URLSessionTransport: HttpTransport {
      static let fallbackTimeout: TimeInterval // 120
      init(configuration: URLSessionConfiguration = .elementXWatch)
      func execute(request: HttpTransportRequest) async throws -> HttpTransportResponse
      static func makeURLRequest(from request: HttpTransportRequest) throws -> URLRequest
  }
  extension URLSessionConfiguration { static var elementXWatch: URLSessionConfiguration }
  // Test support (UnitTests target):
  nonisolated final class StubURLProtocol: URLProtocol {
      typealias Handler = @Sendable (URLRequest, Data?) throws -> (HTTPURLResponse, Data)
      static func install(_ handler: @escaping Handler)
      static func configuration() -> URLSessionConfiguration // .elementXWatch with protocolClasses = [StubURLProtocol.self]
      static var lastRequest: (URLRequest, Data?)? { get }
  }
  ```

- [ ] **Step 1: Write the test support and failing tests**

`UnitTests/Sources/Support/StubURLProtocol.swift`:

```swift
@testable import ElementXWatch
import Foundation
import Synchronization

/// Intercepts URLSession traffic in tests. Install a handler before each test.
nonisolated final class StubURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest, Data?) throws -> (HTTPURLResponse, Data)

    private static let state = Mutex<(handler: Handler?, lastRequest: (URLRequest, Data?)?)>((nil, nil))

    static var lastRequest: (URLRequest, Data?)? {
        state.withLock { $0.lastRequest }
    }

    static func install(_ handler: @escaping Handler) {
        state.withLock { $0 = (handler, nil) }
    }

    static func configuration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.elementXWatch
        configuration.protocolClasses = [StubURLProtocol.self]
        return configuration
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = request.httpBody ?? request.httpBodyStream.map(Self.readAll)
        let handler = Self.state.withLock { state in
            state.lastRequest = (request, body)
            return state.handler
        }
        do {
            guard let handler else { throw URLError(.resourceUnavailable) }
            let (response, data) = try handler(request, body)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

extension HTTPURLResponse {
    static func stub(_ url: URL?, status: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
        HTTPURLResponse(url: url ?? URL(string: "https://example.org")!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
    }
}
```

`UnitTests/Sources/URLSessionTransportTests.swift`:

```swift
@testable import ElementXWatch
import Foundation
import MatrixRustSDK
import Testing

@Suite(.serialized)
struct URLSessionTransportTests {
    @Test
    func forwardsRequestAndResponse() async throws {
        StubURLProtocol.install { _, _ in
            (.stub(URL(string: "https://example.org/_matrix/client/v3/sync"), status: 201, headers: ["ETag": "abc"]), Data("world".utf8))
        }
        let transport = URLSessionTransport(configuration: StubURLProtocol.configuration())

        let response = try await transport.execute(request: .init(method: "PUT",
                                                                  url: "https://example.org/_matrix/client/v3/sync?since=1",
                                                                  headers: [.init(name: "Authorization", value: "Bearer secret")],
                                                                  body: Data("hello".utf8),
                                                                  timeoutMs: nil))

        let (sentRequest, sentBody) = try #require(StubURLProtocol.lastRequest)
        #expect(sentRequest.httpMethod == "PUT")
        #expect(sentRequest.url?.absoluteString == "https://example.org/_matrix/client/v3/sync?since=1")
        #expect(sentRequest.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(sentBody == Data("hello".utf8))
        #expect(response.status == 201)
        #expect(response.body == Data("world".utf8))
        #expect(response.headers.contains { $0.name.lowercased() == "etag" && $0.value == "abc" })
    }

    @Test
    func usesTheSDKTimeout() throws {
        let request = try URLSessionTransport.makeURLRequest(from: .init(method: "GET", url: "https://example.org", headers: [], body: Data(), timeoutMs: 45000))
        #expect(request.timeoutInterval == 45)
    }

    @Test
    func fallsBackToALongTimeoutSoLongPollsAreNotCut() throws {
        let request = try URLSessionTransport.makeURLRequest(from: .init(method: "GET", url: "https://example.org", headers: [], body: Data(), timeoutMs: nil))
        #expect(request.timeoutInterval == URLSessionTransport.fallbackTimeout)
        #expect(URLSessionTransport.fallbackTimeout >= 120)
    }

    @Test
    func emptyBodiesAreNotSent() throws {
        let request = try URLSessionTransport.makeURLRequest(from: .init(method: "GET", url: "https://example.org", headers: [], body: Data(), timeoutMs: nil))
        #expect(request.httpBody == nil)
    }

    @Test
    func networkFailuresBecomeTransportErrors() async {
        StubURLProtocol.install { _, _ in throw URLError(.notConnectedToInternet) }
        let transport = URLSessionTransport(configuration: StubURLProtocol.configuration())

        await #expect(throws: HttpTransportError.self) {
            _ = try await transport.execute(request: .init(method: "GET", url: "https://example.org", headers: [], body: Data(), timeoutMs: nil))
        }
    }

    @Test
    func invalidURLsAreRejected() {
        #expect(throws: HttpTransportError.self) {
            _ = try URLSessionTransport.makeURLRequest(from: .init(method: "GET", url: "not a url", headers: [], body: Data(), timeoutMs: nil))
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the standard test command with `-only-testing:UnitTests/URLSessionTransportTests`.
Expected: build failure `cannot find 'URLSessionTransport' in scope`.

- [ ] **Step 3: Implement**

`Services/Transport/URLSessionTransport.swift`:

```swift
import Foundation
import MatrixRustSDK

/// Executes the Rust SDK's HTTP requests with `URLSession`, the only networking watchOS permits (TN3135).
nonisolated final class URLSessionTransport: HttpTransport {
    /// Used when the SDK gives no timeout; longer than a sync long-poll so it's never cut short.
    static let fallbackTimeout: TimeInterval = 120

    private let session: URLSession

    init(configuration: URLSessionConfiguration = .elementXWatch) {
        session = URLSession(configuration: configuration)
    }

    func execute(request: HttpTransportRequest) async throws -> HttpTransportResponse {
        let urlRequest = try Self.makeURLRequest(from: request)
        let path = urlRequest.url?.path() ?? ""

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HttpTransportError.Network(message: "Received a non-HTTP response")
            }
            MXLog.verbose("\(request.method) \(path) -> \(httpResponse.statusCode)")
            return HttpTransportResponse(status: UInt16(httpResponse.statusCode),
                                         headers: Self.headers(from: httpResponse),
                                         body: data)
        } catch let error as HttpTransportError {
            throw error
        } catch {
            let code = (error as? URLError)?.code.rawValue ?? -1
            MXLog.info("\(request.method) \(path) failed with URLError \(code)")
            throw HttpTransportError.Network(message: error.localizedDescription)
        }
    }

    static func makeURLRequest(from request: HttpTransportRequest) throws -> URLRequest {
        guard let url = URL(string: request.url), url.scheme != nil else {
            throw HttpTransportError.Network(message: "Invalid URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body.isEmpty ? nil : request.body
        urlRequest.timeoutInterval = request.timeoutMs.map { max(TimeInterval($0) / 1000, 1) } ?? fallbackTimeout
        for header in request.headers {
            urlRequest.addValue(header.value, forHTTPHeaderField: header.name)
        }
        return urlRequest
    }

    private static func headers(from response: HTTPURLResponse) -> [HttpHeader] {
        response.allHeaderFields.compactMap { key, value in
            guard let name = key as? String else { return nil }
            return HttpHeader(name: name, value: String(describing: value))
        }
    }
}

extension URLSessionConfiguration {
    /// No caching or cookies (the SDK owns both), no waiting for connectivity (the SDK owns retries).
    nonisolated static var elementXWatch: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = false
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.timeoutIntervalForResource = 300
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        return configuration
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the standard test command with `-only-testing:UnitTests/URLSessionTransportTests`.
Expected: 6 tests passed.

- [ ] **Step 5: Commit**

```bash
git add ElementXWatch/Sources/Services/Transport UnitTests/Sources
git commit -m "Add the URLSession-backed HTTP transport for the Rust SDK

All SDK traffic is executed by URLSession, the only networking API
watchOS allows. SDK timeouts are honoured, with a long fallback so sync
long-polls aren't cut short, and failures are reported as transport
errors so the SDK applies its own retry policy.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

### Task 9: Session persistence — directories, restoration token, keychain, session store

**Files:**
- Create: `ElementXWatch/Sources/Services/Session/SessionDirectories.swift` (derived from iOS)
- Create: `ElementXWatch/Sources/Services/Session/RestorationToken.swift` (derived from iOS)
- Create: `ElementXWatch/Sources/Services/Session/KeychainStore.swift`
- Create: `ElementXWatch/Sources/Services/Session/SessionStore.swift`
- Create: `ElementXWatch/Sources/Services/Session/SessionDelegate.swift`
- Test: `UnitTests/Sources/SessionStoreTests.swift`, `UnitTests/Sources/SessionDelegateTests.swift`

**Interfaces:**
- Produces:
  ```swift
  nonisolated struct SessionDirectories: Hashable, Codable { let dataDirectory: URL; let cacheDirectory: URL; var dataPath: String; var cachePath: String
      init(); init(dataDirectory:cacheDirectory:); func create() throws; func delete(); func isNonTransientUserDataValid() -> Bool }
  extension URL { static var sessionsBaseDirectory: URL; static var sessionCachesBaseDirectory: URL; static var logsDirectory: URL }
  nonisolated struct RestorationToken: Equatable, Codable { let session: MatrixRustSDK.Session; let sessionDirectories: SessionDirectories; let passphrase: Data; let pusherNotificationClientIdentifier: String? }
  // sourcery: AutoMockable
  protocol KeychainStoreProtocol: Sendable { func restorationToken() -> RestorationToken?; func setRestorationToken(_ token: RestorationToken); func removeRestorationToken() }
  nonisolated final class KeychainStore: KeychainStoreProtocol { init(service: String) }
  // sourcery: AutoMockable
  protocol SessionStoreProtocol { var hasSession: Bool { get }; func restorationToken() -> RestorationToken?; func save(_ token: RestorationToken); func clear() }
  final class SessionStore: SessionStoreProtocol { init(keychainStore: KeychainStoreProtocol) }
  nonisolated final class SessionDelegate: ClientSessionDelegate { init(keychainStore: KeychainStoreProtocol) }
  ```

- [ ] **Step 1: Write the failing tests**

`UnitTests/Sources/SessionStoreTests.swift`:

```swift
@testable import ElementXWatch
import Foundation
import MatrixRustSDK
import Testing

@Suite(.serialized)
struct SessionStoreTests {
    @Test
    func noTokenMeansNoSession() {
        let (store, _) = makeStore()
        #expect(!store.hasSession)
        #expect(store.restorationToken() == nil)
    }

    @Test
    func savedTokenWithCryptoStoreIsASession() throws {
        let (store, _) = makeStore()
        let token = try makeToken(withCryptoStore: true)

        store.save(token)

        #expect(store.hasSession)
        #expect(store.restorationToken() == token)
    }

    @Test
    func tokenWithoutCryptoStoreIsDiscarded() throws {
        let (store, keychain) = makeStore()
        let token = try makeToken(withCryptoStore: false)
        store.save(token)

        #expect(!store.hasSession)
        #expect(store.restorationToken() == nil)
        #expect(keychain.restorationToken() == nil)
        #expect(!FileManager.default.fileExists(atPath: token.sessionDirectories.dataPath))
    }

    @Test
    func clearRemovesTokenAndFiles() throws {
        let (store, keychain) = makeStore()
        let token = try makeToken(withCryptoStore: true)
        store.save(token)

        store.clear()

        #expect(keychain.restorationToken() == nil)
        #expect(!FileManager.default.fileExists(atPath: token.sessionDirectories.dataPath))
        #expect(!FileManager.default.fileExists(atPath: token.sessionDirectories.cachePath))
    }

    @Test
    func tokenRoundTripsThroughTheKeychain() throws {
        let keychain = KeychainStore(service: "tests.\(UUID().uuidString)")
        let token = try makeToken(withCryptoStore: false)

        keychain.setRestorationToken(token)
        #expect(keychain.restorationToken() == token)

        keychain.removeRestorationToken()
        #expect(keychain.restorationToken() == nil)
    }

    // MARK: - Helpers

    private func makeStore() -> (SessionStore, KeychainStore) {
        let keychain = KeychainStore(service: "tests.\(UUID().uuidString)")
        return (SessionStore(keychainStore: keychain), keychain)
    }
}

func makeToken(withCryptoStore: Bool, userID: String = "@alice:example.org") throws -> RestorationToken {
    let directories = SessionDirectories()
    try directories.create()
    if withCryptoStore {
        FileManager.default.createFile(atPath: directories.dataPath + "/matrix-sdk-crypto.sqlite3", contents: Data())
    }
    return RestorationToken(session: Session(accessToken: "access",
                                             refreshToken: "refresh",
                                             userId: userID,
                                             deviceId: "DEVICE",
                                             homeserverUrl: "https://matrix-client.example.org",
                                             oauthData: nil,
                                             slidingSyncVersion: .native),
                            sessionDirectories: directories,
                            passphrase: Data("passphrase".utf8),
                            pusherNotificationClientIdentifier: nil)
}
```

`UnitTests/Sources/SessionDelegateTests.swift`:

```swift
@testable import ElementXWatch
import Foundation
import MatrixRustSDK
import Testing

@Suite(.serialized)
struct SessionDelegateTests {
    @Test
    func retrievesTheStoredSession() throws {
        let keychain = KeychainStore(service: "tests.\(UUID().uuidString)")
        let token = try makeToken(withCryptoStore: false)
        keychain.setRestorationToken(token)
        let delegate = SessionDelegate(keychainStore: keychain)

        let session = try delegate.retrieveSessionFromKeychain(userId: "@alice:example.org")

        #expect(session.accessToken == "access")
    }

    @Test
    func refusesAnotherUsersSession() throws {
        let keychain = KeychainStore(service: "tests.\(UUID().uuidString)")
        keychain.setRestorationToken(try makeToken(withCryptoStore: false))
        let delegate = SessionDelegate(keychainStore: keychain)

        #expect(throws: (any Error).self) {
            _ = try delegate.retrieveSessionFromKeychain(userId: "@bob:example.org")
        }
    }

    @Test
    func refreshedTokensAreSavedKeepingDirectoriesAndPassphrase() throws {
        let keychain = KeychainStore(service: "tests.\(UUID().uuidString)")
        let original = try makeToken(withCryptoStore: false)
        keychain.setRestorationToken(original)
        let delegate = SessionDelegate(keychainStore: keychain)
        var refreshed = original.session
        refreshed.accessToken = "new-access"

        delegate.saveSessionInKeychain(session: refreshed)

        let stored = try #require(keychain.restorationToken())
        #expect(stored.session.accessToken == "new-access")
        #expect(stored.sessionDirectories == original.sessionDirectories)
        #expect(stored.passphrase == original.passphrase)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the standard test command with `-only-testing:UnitTests/SessionStoreTests -only-testing:UnitTests/SessionDelegateTests`.
Expected: build failure `cannot find 'SessionStore' in scope`.

- [ ] **Step 3: Implement**

`Services/Session/SessionDirectories.swift`: copy iOS `Services/UserSession/SessionDirectories.swift`, then:
- delete `deleteTransientUserData()` and its private helper `deleteFiles(at:with:)`;
- delete the `init(dataDirectory:)` legacy initialiser;
- replace `MXLog.failure(` with `MXLog.error(`;
- replace `FileManager.default.directoryExists(at: x)` with `FileManager.default.fileExists(atPath: x.path(percentEncoded: false))`;
- add the memberwise-style initialiser, `create()` and the base directories:

```swift
nonisolated extension SessionDirectories {
    init(dataDirectory: URL, cacheDirectory: URL) {
        self.dataDirectory = dataDirectory
        self.cacheDirectory = cacheDirectory
    }

    /// The SDK expects both directories to exist before building a client.
    func create() throws {
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

nonisolated extension URL {
    static var sessionsBaseDirectory: URL {
        .applicationSupportDirectory.appending(component: "Sessions", directoryHint: .isDirectory)
    }

    static var sessionCachesBaseDirectory: URL {
        .cachesDirectory.appending(component: "Sessions", directoryHint: .isDirectory)
    }

    static var logsDirectory: URL {
        .cachesDirectory.appending(component: "Logs", directoryHint: .isDirectory)
    }
}
```

Adding `init(dataDirectory:cacheDirectory:)` in an extension keeps the automatic memberwise initialiser from being lost. Keep the struct's existing `init()` (fresh UUID directories).

`Services/Session/RestorationToken.swift`: copy iOS `Services/UserSession/RestorationToken.swift` verbatim, including the `MatrixRustSDK.Session: @retroactive Codable` extension, except:
- in `init(from:)`, replace the `if let cacheDirectory … else SessionDirectories(dataDirectory:)` block with:

```swift
        guard let cacheDirectory else {
            throw DecodingError.dataCorruptedError(forKey: .cacheDirectory, in: container, debugDescription: "Missing cache directory.")
        }
        let sessionDirectories = SessionDirectories(dataDirectory: dataDirectory, cacheDirectory: cacheDirectory)
```

`Services/Session/KeychainStore.swift`:

```swift
import Foundation
import Security

// sourcery: AutoMockable
protocol KeychainStoreProtocol: Sendable {
    func restorationToken() -> RestorationToken?
    func setRestorationToken(_ token: RestorationToken)
    func removeRestorationToken()
}

/// Stores the single signed-in account's restoration token in the keychain.
nonisolated final class KeychainStore: KeychainStoreProtocol {
    private static let account = "restorationToken"

    private let service: String

    init(service: String = "io.ilie.elementx.watch.sessions") {
        self.service = service
    }

    func restorationToken() -> RestorationToken? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound { MXLog.error("Keychain read failed: \(status)") }
            return nil
        }

        do {
            return try JSONDecoder().decode(RestorationToken.self, from: data)
        } catch {
            MXLog.error("Stored restoration token is unreadable: \(error)")
            return nil
        }
    }

    func setRestorationToken(_ token: RestorationToken) {
        guard let data = try? JSONEncoder().encode(token) else {
            return MXLog.error("Failed encoding the restoration token")
        }

        let attributes: [String: Any] = [kSecValueData as String: data,
                                         kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        var status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(baseQuery.merging(attributes) { $1 } as CFDictionary, nil)
        }
        if status != errSecSuccess {
            MXLog.error("Keychain write failed: \(status)")
        }
    }

    func removeRestorationToken() {
        let status = SecItemDelete(baseQuery as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            MXLog.error("Keychain delete failed: \(status)")
        }
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: Self.account]
    }
}
```

`Services/Session/SessionStore.swift`:

```swift
import Foundation

// sourcery: AutoMockable
protocol SessionStoreProtocol {
    /// Whether a restorable session exists (token present and the crypto store still on disk).
    var hasSession: Bool { get }
    /// The validated token, or `nil` (invalid sessions are cleared).
    func restorationToken() -> RestorationToken?
    func save(_ token: RestorationToken)
    /// Removes the token and deletes the session's files.
    func clear()
}

final class SessionStore: SessionStoreProtocol {
    private let keychainStore: KeychainStoreProtocol

    init(keychainStore: KeychainStoreProtocol) {
        self.keychainStore = keychainStore
    }

    var hasSession: Bool {
        restorationToken() != nil
    }

    func restorationToken() -> RestorationToken? {
        guard let token = keychainStore.restorationToken() else { return nil }

        // A token without its crypto store can't decrypt anything; start over instead of limping on.
        guard token.sessionDirectories.isNonTransientUserDataValid() else {
            MXLog.error("Crypto store missing for \(token.session.userId), clearing the session")
            clear(token)
            return nil
        }

        return token
    }

    func save(_ token: RestorationToken) {
        keychainStore.setRestorationToken(token)
    }

    func clear() {
        if let token = keychainStore.restorationToken() {
            clear(token)
        } else {
            keychainStore.removeRestorationToken()
        }
    }

    private func clear(_ token: RestorationToken) {
        keychainStore.removeRestorationToken()
        token.sessionDirectories.delete()
    }
}
```

`Services/Session/SessionDelegate.swift`:

```swift
import MatrixRustSDK

/// Lets the SDK read the session and persist refreshed OAuth tokens.
nonisolated final class SessionDelegate: ClientSessionDelegate {
    private let keychainStore: KeychainStoreProtocol

    init(keychainStore: KeychainStoreProtocol) {
        self.keychainStore = keychainStore
    }

    func retrieveSessionFromKeychain(userId: String) throws -> Session {
        guard let token = keychainStore.restorationToken(), token.session.userId == userId else {
            throw ClientError.Generic(msg: "No stored session for \(userId)", details: nil)
        }
        return token.session
    }

    func saveSessionInKeychain(session: Session) {
        guard let token = keychainStore.restorationToken() else {
            // The initial save happens after login via SessionStore; nothing to refresh yet.
            return
        }
        MXLog.info("Saving refreshed session for \(session.userId)")
        keychainStore.setRestorationToken(RestorationToken(session: session,
                                                           sessionDirectories: token.sessionDirectories,
                                                           passphrase: token.passphrase,
                                                           pusherNotificationClientIdentifier: token.pusherNotificationClientIdentifier))
    }
}
```

If `ClientError.Generic` has different associated-value labels in the generated bindings, check with `grep -n "case Generic" Packages/MatrixRustSDK/Sources/MatrixRustSDK/matrix_sdk_ffi.swift` and match them.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodegen`, then the standard test command with `-only-testing:UnitTests/SessionStoreTests -only-testing:UnitTests/SessionDelegateTests`.
Expected: 8 tests passed. If the keychain returns `errSecMissingEntitlement` (-34018) in the simulator, confirm Task 6's `CODE_SIGN_IDENTITY[sdk=watchsimulator*] = -` is applied (`xcodebuild -showBuildSettings | grep CODE_SIGN_IDENTITY`).

- [ ] **Step 5: Record provenance and commit**

Append to `SHARED_FROM_IOS.md`:

```markdown
| `ElementXWatch/Sources/Services/Session/SessionDirectories.swift` | `ElementX/Sources/Services/UserSession/SessionDirectories.swift` | Removed transient-data deletion and the legacy init; added `create()` and watch base directories. |
| `ElementXWatch/Sources/Services/Session/RestorationToken.swift` | `ElementX/Sources/Services/UserSession/RestorationToken.swift` | A cache directory is required (no legacy single-directory tokens). |
| `ElementXWatch/Sources/Services/Session/SessionDelegate.swift` | `ElementX/Sources/Services/UserSession/UserSessionStore.swift` (client session delegate) | Single-account keychain store. |
```

```bash
git add ElementXWatch UnitTests SHARED_FROM_IOS.md
git commit -m "Persist the signed-in session in the keychain

Adds the restoration token and session directories from iOS, a
single-account keychain store, a session store that discards sessions
whose crypto store is missing, and the SDK session delegate that saves
refreshed OAuth tokens.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

### Task 10: `ClientFactory`, app settings and Rust tracing

**Files:**
- Create: `ElementXWatch/Sources/Application/WatchAppSettings.swift`
- Create: `ElementXWatch/Sources/Services/Client/ClientFactory.swift` (derived from iOS `Services/Client/ClientFactory.swift`)
- Create: `ElementXWatch/Sources/Other/Tracing.swift`
- Test: `UnitTests/Sources/ClientFactoryTests.swift`

**Interfaces:**
- Consumes: `URLSessionTransport` (Task 8), `SessionDirectories`, `RestorationToken`, `SessionDelegate` (Task 9).
- Produces:
  ```swift
  enum WatchAppSettings { static let defaultServerName: String; static let userAgent: String; static var oAuthConfiguration: OAuthConfiguration; static let keychainService: String }
  // sourcery: AutoMockable
  protocol ClientFactoryProtocol {
      func makeLoginClient(serverName: String, directories: SessionDirectories, passphrase: Data) async throws -> Client
      func makeRestoredClient(token: RestorationToken) async throws -> Client
  }
  nonisolated struct ClientFactory: ClientFactoryProtocol { init(transport: HttpTransport, sessionDelegate: ClientSessionDelegate) }
  enum Tracing { static func setUp() }
  ```

- [ ] **Step 1: Write the failing test**

`UnitTests/Sources/ClientFactoryTests.swift`:

```swift
@testable import ElementXWatch
import Foundation
import MatrixRustSDK
import Testing

@Suite(.serialized)
struct ClientFactoryTests {
    @Test
    func buildsALoginClientEntirelyThroughTheTransport() async throws {
        StubURLProtocol.install { request, _ in
            switch request.url?.path() {
            case "/.well-known/matrix/client":
                return (.stub(request.url, status: 404), Data())
            case "/_matrix/client/versions":
                let body = #"{"versions":["v1.11"],"unstable_features":{"org.matrix.simplified_msc3575":true}}"#
                return (.stub(request.url, status: 200, headers: ["Content-Type": "application/json"]), Data(body.utf8))
            default:
                return (.stub(request.url, status: 404), Data(#"{"errcode":"M_UNRECOGNIZED"}"#.utf8))
            }
        }
        let factory = ClientFactory(transport: URLSessionTransport(configuration: StubURLProtocol.configuration()),
                                    sessionDelegate: SessionDelegate(keychainStore: KeychainStore(service: "tests.\(UUID().uuidString)")))
        let directories = SessionDirectories()
        try directories.create()
        defer { directories.delete() }

        let client = try await factory.makeLoginClient(serverName: "https://example.org",
                                                       directories: directories,
                                                       passphrase: Data(repeating: 7, count: 32))

        #expect(client.homeserver().hasPrefix("https://example.org"))
    }
}
```

In DEBUG the factory points reqwest at `http://127.0.0.1:9`, so this test also proves that client building makes no request outside the transport.

- [ ] **Step 2: Run the test to verify it fails**

Run the standard test command with `-only-testing:UnitTests/ClientFactoryTests`.
Expected: build failure `cannot find 'ClientFactory' in scope`.

- [ ] **Step 3: Implement**

`Application/WatchAppSettings.swift`:

```swift
import Foundation
import MatrixRustSDK

/// Static configuration for the watch app.
nonisolated enum WatchAppSettings {
    static let defaultServerName = "matrix.org"
    static let keychainService = "io.ilie.elementx.watch.sessions"
    static let userAgent = "ElementXWatch/0.1.0 (watchOS)"

    /// OAuth client metadata for dynamic registration with the account's MAS.
    /// All URIs share one host, as MAS requires; the redirect is never used by the device-code QR flow.
    static var oAuthConfiguration: OAuthConfiguration {
        OAuthConfiguration(clientName: "Element X Watch",
                           redirectUri: "https://ilie.io/element-x-watch/oauth",
                           clientUri: "https://ilie.io/element-x-watch",
                           logoUri: "https://ilie.io/element-x-watch/logo.png",
                           tosUri: "https://ilie.io/element-x-watch/terms",
                           policyUri: "https://ilie.io/element-x-watch/privacy",
                           staticRegistrations: [:])
    }
}
```

`Services/Client/ClientFactory.swift`:

```swift
import Foundation
import MatrixRustSDK

// sourcery: AutoMockable
protocol ClientFactoryProtocol {
    func makeLoginClient(serverName: String, directories: SessionDirectories, passphrase: Data) async throws -> Client
    func makeRestoredClient(token: RestorationToken) async throws -> Client
}

/// Builds SDK clients whose HTTP traffic all goes through the given transport.
nonisolated struct ClientFactory: ClientFactoryProtocol {
    private let transport: HttpTransport
    private let sessionDelegate: ClientSessionDelegate

    init(transport: HttpTransport, sessionDelegate: ClientSessionDelegate) {
        self.transport = transport
        self.sessionDelegate = sessionDelegate
    }

    func makeLoginClient(serverName: String, directories: SessionDirectories, passphrase: Data) async throws -> Client {
        try await makeBaseBuilder()
            .slidingSyncVersionBuilder(versionBuilder: .discoverNative)
            .sqliteStore(config: .init(dataPath: directories.dataPath, cachePath: directories.cachePath)
                .highEntropyPassphrase(passphrase: passphrase, base64Variant: .padded))
            .serverNameOrHomeserverUrl(serverNameOrUrl: serverName)
            .build()
    }

    func makeRestoredClient(token: RestorationToken) async throws -> Client {
        let client = try await makeBaseBuilder()
            .sqliteStore(config: .init(dataPath: token.sessionDirectories.dataPath, cachePath: token.sessionDirectories.cachePath)
                .highEntropyPassphrase(passphrase: token.passphrase, base64Variant: .padded))
            .homeserverUrl(url: token.session.homeserverUrl)
            .build()
        try await client.restoreSessionWith(session: token.session, roomLoadSettings: .all)
        return client
    }

    private func makeBaseBuilder() -> ClientBuilder {
        var builder = ClientBuilder()
            .httpTransport(transport: transport)
            .setSessionDelegate(sessionDelegate: sessionDelegate)
            .userAgent(userAgent: WatchAppSettings.userAgent)
            .requestConfig(config: .init(retryLimit: 3, timeout: 30000, maxConcurrentRequests: 4, maxRetryTime: nil))
            .dmRoomDefinition(dmRoomDefinition: .twoMembers)
            .systemIsMemoryConstrained()
            .autoEnableCrossSigning(autoEnableCrossSigning: true)
            .backupDownloadStrategy(backupDownloadStrategy: .afterDecryptionFailure)
            .enableShareHistoryOnInvite(enableShareHistoryOnInvite: true)
            .autoEnableBackups(autoEnableBackups: true)
            .roomKeyRecipientStrategy(strategy: .errorOnVerifiedUserProblem)
            .decryptionSettings(decryptionSettings: .init(senderDeviceTrustRequirement: .untrusted))

        #if DEBUG
        // Tripwire: anything that bypasses the transport hits a closed port and fails loudly.
        builder = builder.proxy(url: "http://127.0.0.1:9")
        #endif

        return builder
    }
}
```

`Other/Tracing.swift`:

```swift
import Foundation
import MatrixRustSDK

/// Sets up Rust SDK logging: system log plus rolling files in Caches/Logs (retrievable from Xcode's Devices window).
enum Tracing {
    static func setUp() {
        let directory = URL.logsDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        #if DEBUG
        let level = LogLevel.debug
        #else
        let level = LogLevel.info
        #endif

        do {
            try initPlatform(config: .init(logLevel: level,
                                           traceLogPacks: [],
                                           extraTargets: [],
                                           writeToStdoutOrSystem: true,
                                           writeToFiles: .init(path: directory.path(percentEncoded: false),
                                                               filePrefix: "rust",
                                                               fileSuffix: "log",
                                                               maxTotalSizeBytes: 20_000_000,
                                                               maxAgeSeconds: 3 * 24 * 60 * 60)),
                             useLightweightTokioRuntime: true)
        } catch {
            MXLog.error("Failed to set up Rust tracing: \(error)")
        }
    }
}
```

If the compiler reports different labels for `RequestConfig`, `TracingConfiguration` or `OAuthConfiguration`, look up the generated `public init(` for that type in `Packages/MatrixRustSDK/Sources/MatrixRustSDK/matrix_sdk_ffi.swift` and match it exactly. Don't add or drop settings.

- [ ] **Step 4: Run the test to verify it passes**

Run the standard test command with `-only-testing:UnitTests/ClientFactoryTests`.
Expected: 1 test passed. A failure mentioning `127.0.0.1:9` / connection refused means an SDK path bypassed the transport. Go back to Tasks 2–4 and fix it.

- [ ] **Step 5: Record provenance and commit**

Append to `SHARED_FROM_IOS.md`:

```markdown
| `ElementXWatch/Sources/Services/Client/ClientFactory.swift` | `ElementX/Sources/Services/Client/ClientFactory.swift` | URLSession transport, memory-constrained, no search index, no automatic back-pagination, DEBUG reqwest tripwire, no app hooks. |
| `ElementXWatch/Sources/Other/Tracing.swift` | `ElementX/Sources/Other/Logging/Tracing.swift` | Minimal file + system logging, no Sentry. |
```

```bash
git add ElementXWatch UnitTests SHARED_FROM_IOS.md
git commit -m "Build SDK clients that talk only through URLSession

Adds the watch ClientFactory (URLSession transport, memory-constrained,
SQLite stores, with a DEBUG tripwire proxy for any request that bypasses the
transport), OAuth client metadata and Rust tracing to rolling log files.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

## Phase C — Session services and QR login

### Task 11: Room summaries and the room list provider

**Files:**
- Create: `ElementXWatch/Sources/Services/Room/RoomSummary.swift`
- Create: `ElementXWatch/Sources/Services/Room/RoomSummaryPreview.swift` (derived from iOS `RoomSummary/RoomMessageEventStringBuilder.swift`)
- Create: `ElementXWatch/Sources/Services/Room/RoomSummaryProvider.swift` (derived from iOS `RoomSummary/RoomSummaryProvider.swift`)
- Modify: `ElementXWatch/Sources/Other/WatchStrings.swift`
- Test: `UnitTests/Sources/RoomSummaryPreviewTests.swift`, `UnitTests/Sources/Support/SDKFixtures.swift`

**Interfaces:**
- Consumes: `ListDiff`, `SDKListener` (Task 7).
- Produces:
  ```swift
  struct RoomSummary: Identifiable, Equatable { let id: String; let name: String; let avatarURL: URL?; let isDirect: Bool
      let lastMessage: String?; let lastMessageDate: Date?; let unreadCount: Int; let hasUnreadMentions: Bool; let isMarkedUnread: Bool
      var hasUnread: Bool; init(roomInfo: RoomInfo, latestEvent: LatestEventValue) }
  enum RoomSummaryPreview { static func text(for latestEvent: LatestEventValue, isDirect: Bool) -> String?; static func date(for latestEvent: LatestEventValue) -> Date?
      static func text(for content: TimelineItemContent) -> String? }
  // sourcery: AutoMockable
  protocol RoomSummaryProviderProtocol: AnyObject { var roomsPublisher: AnyPublisher<[RoomSummary], Never> { get }; func start() async }
  final class RoomSummaryProvider: RoomSummaryProviderProtocol { init(roomListService: RoomListService) }
  // Test fixtures (UnitTests): func textContent(_ body: String) -> TimelineItemContent; func profile(_ name: String?) -> ProfileDetails
  ```

- [ ] **Step 1: Write the fixtures and failing tests**

`UnitTests/Sources/Support/SDKFixtures.swift`:

```swift
import MatrixRustSDK

func messageContent(_ msgType: MessageType, body: String = "", isEdited: Bool = false) -> TimelineItemContent {
    .msgLike(content: MsgLikeContent(kind: .message(content: MessageContent(msgType: msgType, body: body, isEdited: isEdited, mentions: nil)),
                                     inReplyTo: nil,
                                     threadRoot: nil,
                                     threadSummary: nil))
}

func textContent(_ body: String, isEdited: Bool = false) -> TimelineItemContent {
    messageContent(.text(content: TextMessageContent(body: body, formatted: nil)), body: body, isEdited: isEdited)
}

func msgLike(_ kind: MsgLikeKind) -> TimelineItemContent {
    .msgLike(content: MsgLikeContent(kind: kind, inReplyTo: nil, threadRoot: nil, threadSummary: nil))
}

func profile(_ name: String?) -> ProfileDetails {
    .ready(displayName: name, displayNameAmbiguous: false, avatarUrl: nil, status: nil, call: nil)
}

func remoteLatestEvent(_ content: TimelineItemContent, sender: String = "@bob:example.org", name: String? = "Bob", isOwn: Bool = false, timestamp: UInt64 = 1_700_000_000_000) -> LatestEventValue {
    .remote(timestamp: timestamp, sender: sender, isOwn: isOwn, profile: profile(name), content: content)
}
```

If a generated initialiser has different labels (for example `ProfileDetails.ready` in your bindings), match `Packages/MatrixRustSDK/Sources/MatrixRustSDK/matrix_sdk_ffi.swift`.

`UnitTests/Sources/RoomSummaryPreviewTests.swift`:

```swift
@testable import ElementXWatch
import Foundation
import MatrixRustSDK
import Testing

struct RoomSummaryPreviewTests {
    @Test
    func directMessagesHaveNoSenderPrefix() {
        #expect(RoomSummaryPreview.text(for: remoteLatestEvent(textContent("Hi!")), isDirect: true) == "Hi!")
    }

    @Test
    func groupMessagesArePrefixedWithTheSender() {
        #expect(RoomSummaryPreview.text(for: remoteLatestEvent(textContent("Hi!")), isDirect: false) == "Bob: Hi!")
    }

    @Test
    func groupMessagesFallBackToTheUserID() {
        #expect(RoomSummaryPreview.text(for: remoteLatestEvent(textContent("Hi!"), name: nil), isDirect: false) == "@bob:example.org: Hi!")
    }

    @Test
    func ownMessagesArePrefixedWithYou() {
        #expect(RoomSummaryPreview.text(for: remoteLatestEvent(textContent("Hi!"), isOwn: true), isDirect: true) == "You: Hi!")
    }

    @Test
    func specialContentHasReadablePreviews() {
        #expect(RoomSummaryPreview.text(for: msgLike(.redacted)) == WatchStrings.messageDeleted)
        #expect(RoomSummaryPreview.text(for: msgLike(.unableToDecrypt(msg: .unknown))) == WatchStrings.waitingForMessage)
        #expect(RoomSummaryPreview.text(for: messageContent(.emote(content: EmoteMessageContent(body: "waves", formatted: nil)))) == "* waves")
    }

    @Test
    func stateEventsAndEmptyRoomsHaveNoPreview() {
        #expect(RoomSummaryPreview.text(for: LatestEventValue.none, isDirect: true) == nil)
        #expect(RoomSummaryPreview.text(for: .profileChange(displayName: "B", prevDisplayName: "A", avatarUrl: nil, prevAvatarUrl: nil)) == nil)
    }

    @Test
    func dateComesFromTheTimestamp() {
        #expect(RoomSummaryPreview.date(for: remoteLatestEvent(textContent("x"), timestamp: 1_700_000_000_000)) == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(RoomSummaryPreview.date(for: .none) == nil)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the standard test command with `-only-testing:UnitTests/RoomSummaryPreviewTests`.
Expected: build failure `cannot find 'RoomSummaryPreview' in scope`.

- [ ] **Step 3: Implement**

Add to `WatchStrings`:

```swift
    static let you = "You"
    static let messageDeleted = "Message deleted"
    static let waitingForMessage = "Waiting for this message"
    static let photo = "📷 Photo"
    static let video = "🎥 Video"
    static let audio = "🎵 Audio"
    static let file = "📎 File"
    static let location = "📍 Location"
    static let gallery = "🖼️ Gallery"
    static let sticker = "Sticker"
```

`Services/Room/RoomSummaryPreview.swift`:

```swift
import Foundation
import MatrixRustSDK

/// One-line previews for the chats list, derived from iOS's RoomMessageEventStringBuilder.
enum RoomSummaryPreview {
    static func text(for latestEvent: LatestEventValue, isDirect: Bool) -> String? {
        let sender: String
        let senderProfile: ProfileDetails
        let isOwn: Bool
        let content: TimelineItemContent

        switch latestEvent {
        case .none, .remoteInvite:
            return nil
        case .remote(_, let remoteSender, let remoteIsOwn, let remoteProfile, let remoteContent):
            (sender, isOwn, senderProfile, content) = (remoteSender, remoteIsOwn, remoteProfile, remoteContent)
        case .local(_, let localSender, let localProfile, let localContent, _):
            (sender, isOwn, senderProfile, content) = (localSender, true, localProfile, localContent)
        }

        guard let body = text(for: content) else { return nil }

        if isOwn {
            return "\(WatchStrings.you): \(body)"
        } else if isDirect {
            return body
        } else {
            return "\(displayName(from: senderProfile) ?? sender): \(body)"
        }
    }

    static func date(for latestEvent: LatestEventValue) -> Date? {
        switch latestEvent {
        case .none:
            nil
        case .remote(let timestamp, _, _, _, _), .remoteInvite(let timestamp, _, _), .local(let timestamp, _, _, _, _):
            Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        }
    }

    static func text(for content: TimelineItemContent) -> String? {
        guard case .msgLike(let msgLike) = content else { return nil }

        switch msgLike.kind {
        case .message(let message):
            switch message.msgType {
            case .text(let content): return content.body
            case .emote(let content): return "* \(content.body)"
            case .notice(let content): return content.body
            case .image: return WatchStrings.photo
            case .video: return WatchStrings.video
            case .audio: return WatchStrings.audio
            case .file: return WatchStrings.file
            case .location: return WatchStrings.location
            case .gallery: return WatchStrings.gallery
            case .other(_, let body): return body
            }
        case .sticker: return WatchStrings.sticker
        case .poll(let question, _, _, _, _, _, _): return "📊 \(question)"
        case .redacted: return WatchStrings.messageDeleted
        case .unableToDecrypt: return WatchStrings.waitingForMessage
        case .liveLocation: return WatchStrings.location
        case .other: return nil
        }
    }

    static func displayName(from profile: ProfileDetails) -> String? {
        if case .ready(let displayName, _, _, _, _) = profile { displayName } else { nil }
    }
}
```

The `switch`es must be exhaustive against your generated bindings. If the compiler lists a missing case, map media-like cases to their emoji string and anything else to `nil`.

`Services/Room/RoomSummary.swift`:

```swift
import Foundation
import MatrixRustSDK

struct RoomSummary: Identifiable, Equatable {
    let id: String
    let name: String
    let avatarURL: URL?
    let isDirect: Bool
    let lastMessage: String?
    let lastMessageDate: Date?
    let unreadCount: Int
    let hasUnreadMentions: Bool
    let isMarkedUnread: Bool

    var hasUnread: Bool {
        unreadCount > 0 || isMarkedUnread
    }
}

extension RoomSummary {
    init(roomInfo: RoomInfo, latestEvent: LatestEventValue) {
        id = roomInfo.id
        name = roomInfo.displayName ?? roomInfo.rawName ?? roomInfo.id
        avatarURL = roomInfo.avatarUrl.flatMap(URL.init(string:))
        isDirect = roomInfo.isDirect
        lastMessage = RoomSummaryPreview.text(for: latestEvent, isDirect: roomInfo.isDirect)
        lastMessageDate = RoomSummaryPreview.date(for: latestEvent)
        unreadCount = Int(roomInfo.numUnreadMessages)
        hasUnreadMentions = roomInfo.numUnreadMentions > 0
        isMarkedUnread = roomInfo.isMarkedUnread
    }
}
```

`Services/Room/RoomSummaryProvider.swift`:

```swift
import Combine
import MatrixRustSDK

// sourcery: AutoMockable
protocol RoomSummaryProviderProtocol: AnyObject {
    /// DMs and groups (no spaces, no invites), ordered by the SDK (most recent first).
    var roomsPublisher: AnyPublisher<[RoomSummary], Never> { get }
    func start() async
}

final class RoomSummaryProvider: RoomSummaryProviderProtocol {
    private static let filter: RoomListEntriesDynamicFilterKind = .all(filters: [.nonSpace, .joined, .deduplicateVersions])
    private static let pageSize: UInt32 = 200

    private let roomListService: RoomListService
    /// `nil` until the first list arrives, so the chats screen can show a loading state.
    private let roomsSubject = CurrentValueSubject<[RoomSummary]?, Never>(nil)

    private var rooms: [Room] = []
    private var summariesByID: [String: RoomSummary] = [:]
    private var controller: RoomListDynamicEntriesController?
    private var entriesHandle: TaskHandle?
    private var refreshTask: Task<Void, Never>?

    var roomsPublisher: AnyPublisher<[RoomSummary], Never> {
        roomsSubject.compactMap { $0 }.eraseToAnyPublisher()
    }

    init(roomListService: RoomListService) {
        self.roomListService = roomListService
    }

    deinit {
        entriesHandle?.cancel()
        refreshTask?.cancel()
    }

    func start() async {
        guard entriesHandle == nil else { return }

        do {
            let roomList = try await roomListService.allRooms()
            let listener = SDKListener<[RoomListEntriesUpdate]>.onMainActor { [weak self] updates in
                self?.handle(updates)
            }
            let result = roomList.entriesWithDynamicAdapters(pageSize: Self.pageSize, listener: listener)
            controller = result.controller()
            entriesHandle = result.entriesStream()
            _ = controller?.setFilter(kind: Self.filter)
        } catch {
            MXLog.error("Failed starting the room list: \(error)")
        }
    }

    private func handle(_ updates: [RoomListEntriesUpdate]) {
        var touchedIDs = Set<String>()
        for update in updates {
            rooms.apply(ListDiff(update) { room in
                touchedIDs.insert(room.id())
                return room
            })
        }

        let snapshot = rooms
        let previousTask = refreshTask
        // Chained so refreshes apply in order; each only rebuilds the rooms that changed.
        refreshTask = Task { [weak self] in
            await previousTask?.value
            await self?.refreshSummaries(for: snapshot, touchedIDs: touchedIDs)
        }
    }

    private func refreshSummaries(for rooms: [Room], touchedIDs: Set<String>) async {
        for room in rooms {
            let id = room.id()
            guard touchedIDs.contains(id) || summariesByID[id] == nil else { continue }
            do {
                summariesByID[id] = try await RoomSummary(roomInfo: room.roomInfo(), latestEvent: room.latestEvent())
            } catch {
                MXLog.error("Failed loading room info for \(id): \(error)")
            }
        }

        let liveIDs = Set(rooms.map { $0.id() })
        summariesByID = summariesByID.filter { liveIDs.contains($0.key) }
        roomsSubject.send(rooms.compactMap { summariesByID[$0.id()] })
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodegen`, then the standard test command with `-only-testing:UnitTests/RoomSummaryPreviewTests`.
Expected: 7 tests passed.

- [ ] **Step 5: Record provenance and commit**

Append to `SHARED_FROM_IOS.md`:

```markdown
| `ElementXWatch/Sources/Services/Room/RoomSummaryPreview.swift` | `ElementX/Sources/Services/Room/RoomSummary/RoomMessageEventStringBuilder.swift` | Plain strings (no attributed prefixes), fixed English copy. |
| `ElementXWatch/Sources/Services/Room/RoomSummaryProvider.swift` | `ElementX/Sources/Services/Room/RoomSummary/RoomSummaryProvider.swift` | Single fixed filter (non-space, joined, deduplicated), incremental summary rebuilds, no pagination UI. |
```

```bash
git add ElementXWatch UnitTests SHARED_FROM_IOS.md
git commit -m "Add room summaries and the chats list provider

Summaries for DMs and groups come from the SDK's dynamic room list with
spaces and invites filtered out. Only rooms touched by a diff are
rebuilt, and previews follow the iOS message string rules.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

### Task 12: `ClientProxy`

**Files:**
- Create: `ElementXWatch/Sources/Services/Client/ClientProxyProtocol.swift` (derived, slimmed, from iOS)
- Create: `ElementXWatch/Sources/Services/Client/ClientProxy.swift` (derived, slimmed, from iOS)
- Create: `ElementXWatch/Sources/Services/Media/MediaSourceProxy.swift`
- Test: `UnitTests/Sources/ClientProxyMappingTests.swift`

**Interfaces:**
- Consumes: `RoomSummaryProvider` (Task 11), `SDKListener` (Task 7).
- Produces:
  ```swift
  enum SyncState: Equatable { case idle, running, offline, error; init(_ state: SyncServiceState) }
  enum SessionVerification: Equatable { case unknown, verified, unverified; init(_ state: VerificationState) }
  enum ClientProxyAction: Equatable { case authError(isSoftLogout: Bool) }
  struct MediaSourceProxy: Hashable { let source: MediaSource; let url: String; init(source: MediaSource) }
  // sourcery: AutoMockable
  protocol ClientProxyProtocol: AnyObject {
      var userID: String { get }
      var deviceID: String? { get }
      var homeserver: String { get }
      var syncStatePublisher: AnyPublisher<SyncState, Never> { get }
      var verificationStatePublisher: AnyPublisher<SessionVerification, Never> { get }
      var actionsPublisher: AnyPublisher<ClientProxyAction, Never> { get }
      var roomSummaryProvider: RoomSummaryProviderProtocol { get }
      func startSync() async
      func stopSync() async
      func loadDisplayName() async -> String?
      func loadThumbnail(for source: MediaSourceProxy, width: Int, height: Int) async -> Data?
      func logout() async
  }
  final class ClientProxy: ClientProxyProtocol { static func make(client: Client) async throws -> ClientProxy }
  ```
  (Task 17 adds `func timelineProxy(for roomID: String) async -> TimelineProxyProtocol?` to this protocol.)

- [ ] **Step 1: Write the failing test**

`UnitTests/Sources/ClientProxyMappingTests.swift`:

```swift
@testable import ElementXWatch
import MatrixRustSDK
import Testing

struct ClientProxyMappingTests {
    @Test
    func syncStatesMap() {
        #expect(SyncState(.idle) == .idle)
        #expect(SyncState(.terminated) == .idle)
        #expect(SyncState(.running) == .running)
        #expect(SyncState(.offline) == .offline)
        #expect(SyncState(.error) == .error)
    }

    @Test
    func verificationStatesMap() {
        #expect(SessionVerification(.verified) == .verified)
        #expect(SessionVerification(.unverified) == .unverified)
        #expect(SessionVerification(.unknown) == .unknown)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run the standard test command with `-only-testing:UnitTests/ClientProxyMappingTests`.
Expected: build failure `cannot find 'SyncState' in scope`.

- [ ] **Step 3: Implement**

`Services/Media/MediaSourceProxy.swift`:

```swift
import MatrixRustSDK

/// A hashable wrapper around the SDK's `MediaSource` (a class without value semantics).
struct MediaSourceProxy: Hashable {
    let source: MediaSource
    let url: String

    init(source: MediaSource) {
        self.source = source
        url = source.url()
    }

    static func == (lhs: MediaSourceProxy, rhs: MediaSourceProxy) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
```

`Services/Client/ClientProxyProtocol.swift`:

```swift
import Combine
import Foundation
import MatrixRustSDK

enum SyncState: Equatable {
    case idle
    case running
    case offline
    case error

    init(_ state: SyncServiceState) {
        switch state {
        case .idle, .terminated: self = .idle
        case .running: self = .running
        case .offline: self = .offline
        case .error: self = .error
        }
    }
}

enum SessionVerification: Equatable {
    case unknown
    case verified
    case unverified

    init(_ state: VerificationState) {
        switch state {
        case .unknown: self = .unknown
        case .verified: self = .verified
        case .unverified: self = .unverified
        }
    }
}

enum ClientProxyAction: Equatable {
    /// The homeserver rejected our token; the session must be cleared.
    case authError(isSoftLogout: Bool)
}

// sourcery: AutoMockable
protocol ClientProxyProtocol: AnyObject {
    var userID: String { get }
    var deviceID: String? { get }
    var homeserver: String { get }
    var syncStatePublisher: AnyPublisher<SyncState, Never> { get }
    var verificationStatePublisher: AnyPublisher<SessionVerification, Never> { get }
    var actionsPublisher: AnyPublisher<ClientProxyAction, Never> { get }
    var roomSummaryProvider: RoomSummaryProviderProtocol { get }

    func startSync() async
    func stopSync() async
    func loadDisplayName() async -> String?
    func loadThumbnail(for source: MediaSourceProxy, width: Int, height: Int) async -> Data?
    func logout() async
}
```

`Services/Client/ClientProxy.swift`:

```swift
import Combine
import Foundation
import MatrixRustSDK

/// The watch's wrapper around the SDK `Client`, slimmed from iOS's ClientProxy to DMs and groups.
final class ClientProxy: ClientProxyProtocol {
    private let client: Client
    private let syncService: SyncService
    private let syncStateSubject = CurrentValueSubject<SyncState, Never>(.idle)
    private let verificationStateSubject = CurrentValueSubject<SessionVerification, Never>(.unknown)
    private let actionsSubject = PassthroughSubject<ClientProxyAction, Never>()

    private var syncStateHandle: TaskHandle?
    private var verificationStateHandle: TaskHandle?
    private var delegateHandle: TaskHandle?

    let userID: String
    let deviceID: String?
    let roomSummaryProvider: RoomSummaryProviderProtocol

    var homeserver: String { client.homeserver() }
    var syncStatePublisher: AnyPublisher<SyncState, Never> { syncStateSubject.removeDuplicates().eraseToAnyPublisher() }
    var verificationStatePublisher: AnyPublisher<SessionVerification, Never> { verificationStateSubject.removeDuplicates().eraseToAnyPublisher() }
    var actionsPublisher: AnyPublisher<ClientProxyAction, Never> { actionsSubject.eraseToAnyPublisher() }

    static func make(client: Client) async throws -> ClientProxy {
        let syncService = try await client.syncService().withOfflineMode().finish()
        return try ClientProxy(client: client, syncService: syncService)
    }

    private init(client: Client, syncService: SyncService) throws {
        self.client = client
        self.syncService = syncService
        userID = try client.userId()
        deviceID = try? client.deviceId()
        roomSummaryProvider = RoomSummaryProvider(roomListService: syncService.roomListService())

        syncStateHandle = syncService.state(listener: SDKListener<SyncServiceState>.onMainActor { [weak self] state in
            MXLog.info("Sync state: \(state)")
            self?.syncStateSubject.send(SyncState(state))
        })

        let encryption = client.encryption()
        verificationStateSubject.send(SessionVerification(encryption.verificationState()))
        verificationStateHandle = encryption.verificationStateListener(listener: SDKListener<VerificationState>.onMainActor { [weak self] state in
            self?.verificationStateSubject.send(SessionVerification(state))
        })

        delegateHandle = try client.setDelegate(delegate: ClientDelegateForwarder { [weak self] isSoftLogout in
            MXLog.error("Received an auth error (soft logout: \(isSoftLogout))")
            self?.actionsSubject.send(.authError(isSoftLogout: isSoftLogout))
        })
    }

    deinit {
        syncStateHandle?.cancel()
        verificationStateHandle?.cancel()
        delegateHandle?.cancel()
    }

    func startSync() async {
        MXLog.info("Starting sync")
        await syncService.start()
        await roomSummaryProvider.start()
    }

    func stopSync() async {
        MXLog.info("Stopping sync")
        await syncService.stop()
    }

    func loadDisplayName() async -> String? {
        try? await client.displayName()
    }

    func loadThumbnail(for source: MediaSourceProxy, width: Int, height: Int) async -> Data? {
        do {
            return try await client.getMediaThumbnail(mediaSource: source.source, width: UInt64(width), height: UInt64(height))
        } catch {
            MXLog.error("Failed loading a thumbnail: \(error)")
            return nil
        }
    }

    func logout() async {
        await syncService.stop()
        do {
            try await client.logout()
        } catch {
            MXLog.error("Logout request failed, clearing the session anyway: \(error)")
        }
    }
}

/// Forwards the SDK's client delegate callbacks onto the main actor.
private nonisolated final class ClientDelegateForwarder: ClientDelegate {
    private let onAuthError: @Sendable (Bool) -> Void

    init(onAuthError: @escaping @MainActor (Bool) -> Void) {
        let listener = SDKListener<Bool>.onMainActor(onAuthError)
        self.onAuthError = { listener.forward($0) }
    }

    func didReceiveAuthError(isSoftLogout: Bool) {
        onAuthError(isSoftLogout)
    }

    func onBackgroundTaskErrorReport(taskName: String, error: BackgroundTaskFailureReason) {
        MXLog.error("Background task \(taskName) failed: \(error)")
    }
}
```

Add a generic forwarding helper to `Other/SDKListener.swift`, below the conformances:

```swift
nonisolated extension SDKListener {
    /// Delivers a value to the listener's closure (for wrappers that aren't SDK listener protocols).
    func forward(_ value: T) { onUpdateClosure(value) }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodegen`, then the standard test command (full run; this also regenerates mocks).
Expected: all suites pass, including ClientProxyMappingTests (2). `ElementXWatch/Sources/Mocks/Generated/GeneratedMocks.swift` now contains `ClientProxyMock`, `RoomSummaryProviderMock`, `SessionStoreMock`, `KeychainStoreMock` and `ClientFactoryMock`.

- [ ] **Step 5: Record provenance and commit**

Append to `SHARED_FROM_IOS.md`:

```markdown
| `ElementXWatch/Sources/Services/Client/ClientProxyProtocol.swift`, `ClientProxy.swift` | `ElementX/Sources/Services/Client/ClientProxyProtocol.swift`, `ClientProxy.swift` | Reduced to sync, room list, verification state, display name, thumbnails, logout and auth errors. No spaces, calls, pushers, room creation or directory. |
```

```bash
git add ElementXWatch UnitTests SHARED_FROM_IOS.md
git commit -m "Add the watch ClientProxy

Wraps the SDK client with sync start/stop, the room list provider,
verification state, thumbnails, logout and auth-error reporting,
slimmed down from the iOS ClientProxy.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

### Task 13: QR login service

**Files:**
- Create: `ElementXWatch/Sources/Services/Authentication/QRLoginService.swift` (derived from iOS `AuthenticationService.loginWithQRCode`)
- Modify: `ElementXWatch/Sources/Other/WatchStrings.swift`
- Test: `UnitTests/Sources/QRLoginMappingTests.swift`

**Interfaces:**
- Consumes: `ClientFactoryProtocol` (Task 10), `SessionStoreProtocol`, `SessionDirectories`, `RestorationToken` (Task 9), `ClientProxy` (Task 12).
- Produces:
  ```swift
  protocol CheckCodeSending: AnyObject, Sendable { func send(code: UInt8) async throws }  // SDK CheckCodeSender conforms
  enum QRLoginProgress { case starting, showingQRCode(Data), enteringCheckCode(CheckCodeSending), waitingForApproval(userCode: String), syncingSecrets
      init?(_ progress: GeneratedQrLoginProgress) }
  enum QRLoginError: Error, Equatable { case expired, declined, cancelled, insecureConnection, linkingNotSupported, serverNotSupported, otherDeviceNotSignedIn, unknown
      init(_ error: HumanQrLoginError); var message: String }
  // sourcery: AutoMockable
  protocol QRLoginServiceProtocol { func loginWithGeneratedQRCode(onProgress: @escaping @MainActor (QRLoginProgress) -> Void) async -> Result<ClientProxyProtocol, QRLoginError> }
  final class QRLoginService: QRLoginServiceProtocol { init(clientFactory: ClientFactoryProtocol, sessionStore: SessionStoreProtocol) }
  ```

- [ ] **Step 1: Write the failing tests**

`UnitTests/Sources/QRLoginMappingTests.swift`:

```swift
@testable import ElementXWatch
import MatrixRustSDK
import Testing

struct QRLoginMappingTests {
    @Test
    func errorsMapToUserFacingCases() {
        #expect(QRLoginError(.Expired) == .expired)
        #expect(QRLoginError(.Declined) == .declined)
        #expect(QRLoginError(.Cancelled) == .cancelled)
        #expect(QRLoginError(.ConnectionInsecure) == .insecureConnection)
        #expect(QRLoginError(.CheckCodeCannotBeSent) == .insecureConnection)
        #expect(QRLoginError(.LinkingNotSupported) == .linkingNotSupported)
        #expect(QRLoginError(.SlidingSyncNotAvailable) == .serverNotSupported)
        #expect(QRLoginError(.OAuthMetadataInvalid) == .serverNotSupported)
        #expect(QRLoginError(.OtherDeviceNotSignedIn) == .otherDeviceNotSignedIn)
        #expect(QRLoginError(.Unknown) == .unknown)
    }

    @Test
    func everyErrorHasAMessage() {
        let errors: [QRLoginError] = [.expired, .declined, .cancelled, .insecureConnection, .linkingNotSupported, .serverNotSupported, .otherDeviceNotSignedIn, .unknown]
        for error in errors {
            #expect(!error.message.isEmpty)
        }
    }

    @Test
    func doneIsNotAUserVisibleStep() {
        #expect(QRLoginProgress(.done).map(\.description) == nil)
        if case .waitingForApproval(let code) = QRLoginProgress(.waitingForToken(userCode: "ABCD")) {
            #expect(code == "ABCD")
        } else {
            Issue.record("Expected waitingForApproval")
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the standard test command with `-only-testing:UnitTests/QRLoginMappingTests`.
Expected: build failure `cannot find 'QRLoginError' in scope`.

- [ ] **Step 3: Implement**

Add to `WatchStrings`:

```swift
    static let qrErrorExpired = "The code expired. Try again."
    static let qrErrorDeclined = "Sign-in was declined on your phone."
    static let qrErrorCancelled = "Sign-in was cancelled."
    static let qrErrorInsecure = "The codes didn't match. Try again."
    static let qrErrorLinkingNotSupported = "Your phone can't link devices. Update Element X and turn on Link new device."
    static let qrErrorServerNotSupported = "Your server doesn't support signing in this way."
    static let qrErrorOtherDeviceNotSignedIn = "Element X on your phone isn't signed in."
    static let qrErrorUnknown = "Something went wrong. Try again."
```

`Services/Authentication/QRLoginService.swift`:

```swift
import Foundation
import MatrixRustSDK
import Security

protocol CheckCodeSending: AnyObject, Sendable {
    func send(code: UInt8) async throws
}

extension CheckCodeSender: CheckCodeSending { }

enum QRLoginProgress {
    case starting
    /// The QR code bytes for the phone to scan.
    case showingQRCode(Data)
    /// The phone shows a 2-digit code that the user must enter.
    case enteringCheckCode(CheckCodeSending)
    /// Waiting for the user to approve on the phone.
    case waitingForApproval(userCode: String)
    case syncingSecrets

    init?(_ progress: GeneratedQrLoginProgress) {
        switch progress {
        case .starting: self = .starting
        case .qrReady(let qrCode): self = .showingQRCode(qrCode.toBytes())
        case .qrScanned(let sender): self = .enteringCheckCode(sender)
        case .waitingForToken(let userCode): self = .waitingForApproval(userCode: userCode)
        case .syncingSecrets: self = .syncingSecrets
        case .done: return nil // The app still has to set up the session.
        }
    }
}

enum QRLoginError: Error, Equatable {
    case expired
    case declined
    case cancelled
    case insecureConnection
    case linkingNotSupported
    case serverNotSupported
    case otherDeviceNotSignedIn
    case unknown

    init(_ error: HumanQrLoginError) {
        switch error {
        case .Expired: self = .expired
        case .Declined: self = .declined
        case .Cancelled: self = .cancelled
        case .ConnectionInsecure, .CheckCodeAlreadySent, .CheckCodeCannotBeSent: self = .insecureConnection
        case .LinkingNotSupported, .UnsupportedQrCodeType: self = .linkingNotSupported
        case .SlidingSyncNotAvailable, .OAuthMetadataInvalid, .NotFound: self = .serverNotSupported
        case .OtherDeviceNotSignedIn: self = .otherDeviceNotSignedIn
        case .Unknown, .ContinuationAlreadySent, .ContinuationCannotBeSent: self = .unknown
        }
    }

    var message: String {
        switch self {
        case .expired: WatchStrings.qrErrorExpired
        case .declined: WatchStrings.qrErrorDeclined
        case .cancelled: WatchStrings.qrErrorCancelled
        case .insecureConnection: WatchStrings.qrErrorInsecure
        case .linkingNotSupported: WatchStrings.qrErrorLinkingNotSupported
        case .serverNotSupported: WatchStrings.qrErrorServerNotSupported
        case .otherDeviceNotSignedIn: WatchStrings.qrErrorOtherDeviceNotSignedIn
        case .unknown: WatchStrings.qrErrorUnknown
        }
    }
}

// sourcery: AutoMockable
protocol QRLoginServiceProtocol {
    /// Runs the MSC4108 flow where this device shows the QR code. On success the session is saved.
    func loginWithGeneratedQRCode(onProgress: @escaping @MainActor (QRLoginProgress) -> Void) async -> Result<ClientProxyProtocol, QRLoginError>
}

final class QRLoginService: QRLoginServiceProtocol {
    private let clientFactory: ClientFactoryProtocol
    private let sessionStore: SessionStoreProtocol

    init(clientFactory: ClientFactoryProtocol, sessionStore: SessionStoreProtocol) {
        self.clientFactory = clientFactory
        self.sessionStore = sessionStore
    }

    func loginWithGeneratedQRCode(onProgress: @escaping @MainActor (QRLoginProgress) -> Void) async -> Result<ClientProxyProtocol, QRLoginError> {
        let directories = SessionDirectories()
        let passphrase = Self.makePassphrase()

        do {
            try directories.create()
            let client = try await clientFactory.makeLoginClient(serverName: WatchAppSettings.defaultServerName,
                                                                 directories: directories,
                                                                 passphrase: passphrase)
            let handler = client.newLoginWithQrCodeHandler(oauthConfiguration: WatchAppSettings.oAuthConfiguration)
            let listener = SDKListener<GeneratedQrLoginProgress>.onMainActor { progress in
                if let progress = QRLoginProgress(progress) {
                    onProgress(progress)
                }
            }

            try await handler.generate(progressListener: listener)
            try Task.checkCancellation()

            sessionStore.save(RestorationToken(session: try client.session(),
                                               sessionDirectories: directories,
                                               passphrase: passphrase,
                                               pusherNotificationClientIdentifier: nil))
            MXLog.info("QR login succeeded for \(try client.userId())")
            return .success(try await ClientProxy.make(client: client))
        } catch let error as HumanQrLoginError {
            MXLog.error("QR login failed: \(error)")
            directories.delete()
            return .failure(QRLoginError(error))
        } catch is CancellationError {
            directories.delete()
            return .failure(.cancelled)
        } catch {
            MXLog.error("QR login failed unexpectedly: \(error)")
            sessionStore.clear()
            directories.delete()
            return .failure(.unknown)
        }
    }

    private static func makePassphrase() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            fatalError("Unable to generate a secure passphrase")
        }
        return Data(bytes)
    }
}
```

Add a case-name-only description, which the tests use and which keeps the QR bytes and check-code sender out of the logs:

```swift
extension QRLoginProgress: CustomStringConvertible {
    var description: String {
        switch self {
        case .starting: "starting"
        case .showingQRCode: "showingQRCode"
        case .enteringCheckCode: "enteringCheckCode"
        case .waitingForApproval: "waitingForApproval"
        case .syncingSecrets: "syncingSecrets"
        }
    }
}
```

If the compiler asks for `@retroactive` on `extension CheckCodeSender: CheckCodeSending`, add it.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodegen`, then the standard test command with `-only-testing:UnitTests/QRLoginMappingTests`.
Expected: 3 tests passed.

- [ ] **Step 5: Record provenance and commit**

Append to `SHARED_FROM_IOS.md`:

```markdown
| `ElementXWatch/Sources/Services/Authentication/QRLoginService.swift` | `ElementX/Sources/Services/Authentication/AuthenticationService.swift` (`loginWithQRCode`) + `AuthenticationServiceProtocol.swift` (`QRLoginProgress`, `QRCodeLoginError`) | Uses `LoginWithQrCodeHandler.generate` (this device shows the QR) instead of `scan`; fixed server `matrix.org`; watch OAuth metadata. |
```

```bash
git add ElementXWatch UnitTests SHARED_FROM_IOS.md
git commit -m "Add QR code login where the watch displays the code

Runs the MSC4108 generate flow: the watch shows a QR code, the phone
scans it, the user enters the check code and approves on the phone.
The resulting session is saved to the keychain and wrapped in a
ClientProxy. SDK errors map to user-facing messages.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

### Task 14: QR login screen and authentication flow

**Files:**
- Create: `ElementXWatch/Sources/Screens/QRLoginScreen/QRLoginScreenModels.swift`
- Create: `ElementXWatch/Sources/Screens/QRLoginScreen/QRLoginScreenViewModelProtocol.swift`
- Create: `ElementXWatch/Sources/Screens/QRLoginScreen/QRLoginScreenViewModel.swift`
- Create: `ElementXWatch/Sources/Screens/QRLoginScreen/QRLoginScreenCoordinator.swift`
- Create: `ElementXWatch/Sources/Screens/QRLoginScreen/View/QRLoginScreen.swift`
- Create: `ElementXWatch/Sources/Screens/QRLoginScreen/View/QRCodeView.swift`
- Create: `ElementXWatch/Sources/FlowCoordinators/AuthenticationFlowCoordinator.swift`
- Modify: `ElementXWatch/Sources/Other/WatchStrings.swift`
- Test: `UnitTests/Sources/QRLoginScreenViewModelTests.swift`, `UnitTests/Sources/QRCodeViewTests.swift`

**Interfaces:**
- Consumes: `QRLoginServiceProtocol`, `QRLoginProgress`, `QRLoginError`, `CheckCodeSending` (Task 13); `StateStoreViewModelV2`, `CoordinatorProtocol` (Task 7).
- Produces:
  ```swift
  enum QRLoginScreenStep: Equatable { case intro, preparing, showingQRCode(Data), enteringCheckCode, sendingCheckCode, waitingForApproval(userCode: String), syncingSecrets, failed(QRLoginError) }
  struct QRLoginScreenViewState: BindableState { var step: QRLoginScreenStep; var bindings: QRLoginScreenBindings }
  struct QRLoginScreenBindings { var checkCode: Int }  // 0...99
  enum QRLoginScreenViewAction { case start, submitCheckCode, retry, cancel }
  enum QRLoginScreenViewModelAction { case signedIn(ClientProxyProtocol) }
  final class QRLoginScreenViewModel { init(qrLoginService: QRLoginServiceProtocol); var actionsPublisher: AnyPublisher<QRLoginScreenViewModelAction, Never> }
  final class QRLoginScreenCoordinator: CoordinatorProtocol { init(qrLoginService: QRLoginServiceProtocol); var actionsPublisher: AnyPublisher<QRLoginScreenViewModelAction, Never> }
  enum QRCodeMatrix { static func modules(for data: Data) throws -> [[Bool]] }
  final class AuthenticationFlowCoordinator: CoordinatorProtocol { init(qrLoginService: QRLoginServiceProtocol); var signedInPublisher: AnyPublisher<ClientProxyProtocol, Never> }
  ```

- [ ] **Step 1: Write the failing tests**

`UnitTests/Sources/QRLoginScreenViewModelTests.swift`:

```swift
import Combine
@testable import ElementXWatch
import Foundation
import Testing

@Suite
struct QRLoginScreenViewModelTests {
    @Test
    func progressDrivesTheSteps() async throws {
        let service = QRLoginServiceProtocolMock()
        let gate = AsyncGate()
        service.loginWithGeneratedQRCodeOnProgressClosure = { onProgress in
            await onProgress(.showingQRCode(Data([1, 2])))
            await onProgress(.waitingForApproval(userCode: "XY12"))
            await gate.wait()
            return .failure(.declined)
        }
        let viewModel = QRLoginScreenViewModel(qrLoginService: service)

        viewModel.context.send(viewAction: .start)
        try await waitUntil { viewModel.context.viewState.step == .waitingForApproval(userCode: "XY12") }
        await gate.open()

        try await waitUntil { viewModel.context.viewState.step == .failed(.declined) }
    }

    @Test
    func successEmitsSignedIn() async throws {
        let service = QRLoginServiceProtocolMock()
        let clientProxy = ClientProxyMock()
        service.loginWithGeneratedQRCodeOnProgressClosure = { _ in .success(clientProxy) }
        let viewModel = QRLoginScreenViewModel(qrLoginService: service)
        var signedIn: ClientProxyProtocol?
        let cancellable = viewModel.actionsPublisher.sink { action in
            if case .signedIn(let proxy) = action { signedIn = proxy }
        }

        viewModel.context.send(viewAction: .start)

        try await waitUntil { signedIn != nil }
        #expect(signedIn === clientProxy)
        cancellable.cancel()
    }

    @Test
    func retryStartsAFreshFlow() async throws {
        let service = QRLoginServiceProtocolMock()
        service.loginWithGeneratedQRCodeOnProgressClosure = { _ in .failure(.expired) }
        let viewModel = QRLoginScreenViewModel(qrLoginService: service)
        viewModel.context.send(viewAction: .start)
        try await waitUntil { viewModel.context.viewState.step == .failed(.expired) }

        service.loginWithGeneratedQRCodeOnProgressClosure = { onProgress in
            await onProgress(.showingQRCode(Data([9])))
            return await withCheckedContinuation { _ in } // Stays on the QR code.
        }
        viewModel.context.send(viewAction: .retry)

        try await waitUntil { viewModel.context.viewState.step == .showingQRCode(Data([9])) }
        #expect(service.loginWithGeneratedQRCodeOnProgressCallsCount == 2)
    }

    @Test
    func cancelReturnsToIntroAndIgnoresLateUpdates() async throws {
        let service = QRLoginServiceProtocolMock()
        let gate = AsyncGate()
        service.loginWithGeneratedQRCodeOnProgressClosure = { onProgress in
            await onProgress(.showingQRCode(Data([1])))
            await gate.wait()
            await onProgress(.syncingSecrets)
            return .failure(.unknown)
        }
        let viewModel = QRLoginScreenViewModel(qrLoginService: service)
        viewModel.context.send(viewAction: .start)
        try await waitUntil { viewModel.context.viewState.step == .showingQRCode(Data([1])) }

        viewModel.context.send(viewAction: .cancel)
        await gate.open()
        for _ in 0..<20 { await Task.yield() }

        #expect(viewModel.context.viewState.step == .intro)
    }

    @Test
    func checkCodeIsSentAndFailureIsShown() async throws {
        let sender = FakeCheckCodeSender(shouldFail: true)
        let service = QRLoginServiceProtocolMock()
        service.loginWithGeneratedQRCodeOnProgressClosure = { onProgress in
            await onProgress(.enteringCheckCode(sender))
            return await withCheckedContinuation { _ in }
        }
        let viewModel = QRLoginScreenViewModel(qrLoginService: service)
        viewModel.context.send(viewAction: .start)
        try await waitUntil { viewModel.context.viewState.step == .enteringCheckCode }

        viewModel.context.checkCode = 42
        viewModel.context.send(viewAction: .submitCheckCode)

        try await waitUntil { viewModel.context.viewState.step == .failed(.insecureConnection) }
        #expect(await sender.sentCodes == [42])
    }
}

// MARK: - Helpers

actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }
}

final actor FakeCheckCodeSender: CheckCodeSending {
    private let shouldFail: Bool
    private(set) var sentCodes: [UInt8] = []

    init(shouldFail: Bool) {
        self.shouldFail = shouldFail
    }

    func send(code: UInt8) async throws {
        sentCodes.append(code)
        if shouldFail { throw CancellationError() }
    }
}

/// Polls a main-actor condition, yielding between checks (fails after ~2 s).
func waitUntil(_ condition: @MainActor () -> Bool) async throws {
    for _ in 0..<200 {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Condition not met in time")
}
```

(`CheckCodeSending` requires `AnyObject`; an `actor` satisfies it.)

`UnitTests/Sources/QRCodeViewTests.swift`:

```swift
@testable import ElementXWatch
import Foundation
import Testing

struct QRCodeViewTests {
    @Test
    func encodesBinaryDataIntoASquareMatrix() throws {
        let modules = try QRCodeMatrix.modules(for: Data((0..<100).map { UInt8($0) }))
        #expect(!modules.isEmpty)
        #expect(modules.allSatisfy { $0.count == modules.count })
        #expect(modules[0][0]) // Finder pattern corner is dark.
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodegen`, then the standard test command with `-only-testing:UnitTests/QRLoginScreenViewModelTests -only-testing:UnitTests/QRCodeViewTests`.
Expected: build failure `cannot find 'QRLoginScreenViewModel' in scope`.

- [ ] **Step 3: Implement the models, view model and coordinator**

Add to `WatchStrings`:

```swift
    static let signInTitle = "Sign in with your iPhone"
    static let signInInstructions = "On your iPhone open Element X → Settings → Link new device → Link desktop computer, then scan the code."
    static let signInStart = "Show code"
    static let preparing = "Preparing…"
    static let scanWithPhone = "Scan with Element X"
    static let enterCheckCode = "Enter the code shown on your iPhone"
    static let confirm = "Confirm"
    static let approveOnPhone = "Approve on your iPhone"
    static let approvalCode = "Code"
    static let syncingKeys = "Securing your messages…"
```

`QRLoginScreenModels.swift`:

```swift
import Foundation

enum QRLoginScreenViewModelAction {
    case signedIn(ClientProxyProtocol)
}

enum QRLoginScreenStep: Equatable {
    case intro
    case preparing
    case showingQRCode(Data)
    case enteringCheckCode
    case sendingCheckCode
    case waitingForApproval(userCode: String)
    case syncingSecrets
    case failed(QRLoginError)
}

struct QRLoginScreenViewState: BindableState {
    var step: QRLoginScreenStep = .intro
    var bindings = QRLoginScreenBindings()
}

struct QRLoginScreenBindings {
    /// The 2-digit code from the phone, picked with the Digital Crown.
    var checkCode = 0
}

enum QRLoginScreenViewAction {
    case start
    case submitCheckCode
    case retry
    case cancel
}
```

`QRLoginScreenViewModelProtocol.swift`:

```swift
import Combine

protocol QRLoginScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<QRLoginScreenViewModelAction, Never> { get }
    var context: QRLoginScreenViewModel.Context { get }
}
```

`QRLoginScreenViewModel.swift`:

```swift
import Combine
import Foundation

typealias QRLoginScreenViewModelType = StateStoreViewModelV2<QRLoginScreenViewState, QRLoginScreenViewAction>

final class QRLoginScreenViewModel: QRLoginScreenViewModelType, QRLoginScreenViewModelProtocol {
    private let qrLoginService: QRLoginServiceProtocol
    private let actionsSubject = PassthroughSubject<QRLoginScreenViewModelAction, Never>()

    private var loginTask: Task<Void, Never>?
    private var checkCodeSender: CheckCodeSending?
    /// Identifies the current attempt so updates from a cancelled one are ignored.
    private var attempt = 0

    var actionsPublisher: AnyPublisher<QRLoginScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(qrLoginService: QRLoginServiceProtocol) {
        self.qrLoginService = qrLoginService
        super.init(initialViewState: QRLoginScreenViewState())
    }

    override func process(viewAction: QRLoginScreenViewAction) {
        switch viewAction {
        case .start, .retry:
            startLogin()
        case .submitCheckCode:
            submitCheckCode()
        case .cancel:
            stopLogin()
            state.step = .intro
        }
    }

    private func startLogin() {
        stopLogin()
        state.bindings.checkCode = 0
        state.step = .preparing

        let currentAttempt = attempt
        loginTask = Task { [weak self, qrLoginService] in
            let result = await qrLoginService.loginWithGeneratedQRCode { [weak self] progress in
                guard let self, attempt == currentAttempt else { return }
                handle(progress)
            }
            guard let self, attempt == currentAttempt else { return }

            switch result {
            case .success(let clientProxy):
                actionsSubject.send(.signedIn(clientProxy))
            case .failure(let error):
                state.step = .failed(error)
            }
        }
    }

    private func stopLogin() {
        attempt += 1
        loginTask?.cancel()
        loginTask = nil
        checkCodeSender = nil
    }

    private func handle(_ progress: QRLoginProgress) {
        MXLog.info("QR login progress: \(progress)")
        switch progress {
        case .starting:
            state.step = .preparing
        case .showingQRCode(let data):
            state.step = .showingQRCode(data)
        case .enteringCheckCode(let sender):
            checkCodeSender = sender
            state.step = .enteringCheckCode
        case .waitingForApproval(let userCode):
            state.step = .waitingForApproval(userCode: userCode)
        case .syncingSecrets:
            state.step = .syncingSecrets
        }
    }

    private func submitCheckCode() {
        guard let checkCodeSender else { return }
        let code = UInt8(clamping: state.bindings.checkCode)
        let currentAttempt = attempt
        state.step = .sendingCheckCode

        Task { [weak self] in
            do {
                try await checkCodeSender.send(code: code)
            } catch {
                MXLog.error("Failed sending the check code: \(error)")
                guard let self, attempt == currentAttempt else { return }
                stopLogin()
                state.step = .failed(.insecureConnection)
            }
        }
    }
}
```

`QRLoginScreenCoordinator.swift`:

```swift
import Combine
import SwiftUI

final class QRLoginScreenCoordinator: CoordinatorProtocol {
    private let viewModel: QRLoginScreenViewModel

    var actionsPublisher: AnyPublisher<QRLoginScreenViewModelAction, Never> {
        viewModel.actionsPublisher
    }

    init(qrLoginService: QRLoginServiceProtocol) {
        viewModel = QRLoginScreenViewModel(qrLoginService: qrLoginService)
    }

    func toPresentable() -> AnyView {
        AnyView(QRLoginScreen(context: viewModel.context))
    }
}
```

`FlowCoordinators/AuthenticationFlowCoordinator.swift`:

```swift
import Combine
import SwiftUI

/// The signed-out flow: currently only QR login.
final class AuthenticationFlowCoordinator: CoordinatorProtocol {
    private let screenCoordinator: QRLoginScreenCoordinator
    private let signedInSubject = PassthroughSubject<ClientProxyProtocol, Never>()
    private var cancellables = Set<AnyCancellable>()

    var signedInPublisher: AnyPublisher<ClientProxyProtocol, Never> {
        signedInSubject.eraseToAnyPublisher()
    }

    init(qrLoginService: QRLoginServiceProtocol) {
        screenCoordinator = QRLoginScreenCoordinator(qrLoginService: qrLoginService)
    }

    func start() {
        screenCoordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .signedIn(let clientProxy):
                    self?.signedInSubject.send(clientProxy)
                }
            }
            .store(in: &cancellables)
    }

    func toPresentable() -> AnyView {
        AnyView(NavigationStack { screenCoordinator.toPresentable() })
    }
}
```

- [ ] **Step 4: Implement the views**

`View/QRCodeView.swift`:

```swift
import Foundation
import QRCodeGenerator
import SwiftUI

enum QRCodeMatrix {
    /// The QR modules (true = dark) for binary data, with low error correction to keep modules large.
    static func modules(for data: Data) throws -> [[Bool]] {
        let code = try QRCode.encode(binary: [UInt8](data), ecl: .low)
        return (0..<code.size).map { y in (0..<code.size).map { x in code.getModule(x: x, y: y) } }
    }
}

/// Renders QR data as crisp black-on-white modules with a quiet zone.
struct QRCodeView: View {
    let data: Data

    var body: some View {
        if let modules = try? QRCodeMatrix.modules(for: data) {
            Canvas { context, size in
                let quietZone = 2
                let count = modules.count + quietZone * 2
                let moduleSize = min(size.width, size.height) / CGFloat(count)
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                for (y, row) in modules.enumerated() {
                    for (x, isDark) in row.enumerated() where isDark {
                        let rect = CGRect(x: CGFloat(x + quietZone) * moduleSize,
                                          y: CGFloat(y + quietZone) * moduleSize,
                                          width: moduleSize,
                                          height: moduleSize)
                        context.fill(Path(rect), with: .color(.black))
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .accessibilityLabel(WatchStrings.scanWithPhone)
        } else {
            Text(WatchStrings.qrErrorUnknown)
        }
    }
}
```

`View/QRLoginScreen.swift`:

```swift
import SwiftUI

struct QRLoginScreen: View {
    @Bindable var context: QRLoginScreenViewModel.Context

    var body: some View {
        content
            .navigationTitle(WatchStrings.appName)
    }

    @ViewBuilder
    private var content: some View {
        switch context.viewState.step {
        case .intro:
            ScrollView {
                VStack(spacing: 8) {
                    Text(WatchStrings.signInTitle).font(.headline)
                    Text(WatchStrings.signInInstructions)
                        .font(.footnote)
                        .foregroundStyle(Color.compound.textSecondary)
                    Button(WatchStrings.signInStart) { context.send(viewAction: .start) }
                        .tint(Color.compound.bgAccentRest)
                }
            }
        case .preparing, .sendingCheckCode:
            ProgressView(WatchStrings.preparing)
        case .showingQRCode(let data):
            QRCodeView(data: data)
                .ignoresSafeArea(edges: .bottom)
                .toolbar { cancelButton }
        case .enteringCheckCode:
            checkCodeEntry
        case .waitingForApproval(let userCode):
            VStack(spacing: 6) {
                ProgressView()
                Text(WatchStrings.approveOnPhone).font(.headline)
                Text("\(WatchStrings.approvalCode): \(userCode)").font(.footnote.monospaced())
            }
            .toolbar { cancelButton }
        case .syncingSecrets:
            ProgressView(WatchStrings.syncingKeys)
        case .failed(let error):
            ScrollView {
                VStack(spacing: 8) {
                    Text(error.message).multilineTextAlignment(.center)
                    Button(WatchStrings.tryAgain) { context.send(viewAction: .retry) }
                }
            }
        }
    }

    private var checkCodeEntry: some View {
        VStack(spacing: 4) {
            Text(WatchStrings.enterCheckCode).font(.footnote).multilineTextAlignment(.center)
            Picker(WatchStrings.approvalCode, selection: $context.checkCode) {
                ForEach(0..<100, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .labelsHidden()
            .frame(height: 60)
            Button(WatchStrings.confirm) { context.send(viewAction: .submitCheckCode) }
        }
        .toolbar { cancelButton }
    }

    private var cancelButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(WatchStrings.cancel) { context.send(viewAction: .cancel) }
        }
    }
}

// MARK: - Previews

struct QRLoginScreen_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(steps, id: \.0) { name, step in
            NavigationStack { QRLoginScreen(context: makeViewModel(step: step).context) }
                .previewDisplayName(name)
        }
    }

    static let steps: [(String, QRLoginScreenStep)] = [
        ("Intro", .intro),
        ("Preparing", .preparing),
        ("QR code", .showingQRCode(Data((0..<120).map { UInt8($0) }))),
        ("Check code", .enteringCheckCode),
        ("Approve", .waitingForApproval(userCode: "7XK2")),
        ("Syncing", .syncingSecrets),
        ("Failed", .failed(.expired))
    ]

    static func makeViewModel(step: QRLoginScreenStep) -> QRLoginScreenViewModel {
        let viewModel = QRLoginScreenViewModel(qrLoginService: QRLoginServiceProtocolMock())
        viewModel.state.step = step
        return viewModel
    }
}
```

`QRLoginServiceProtocolMock` lives in the app target (`Mocks/Generated`), so previews can use it.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `xcodegen`, then the standard test command with `-only-testing:UnitTests/QRLoginScreenViewModelTests -only-testing:UnitTests/QRCodeViewTests`.
Expected: 6 tests passed. If a mock property name differs, check `ElementXWatch/Sources/Mocks/Generated/GeneratedMocks.swift` for `QRLoginServiceProtocolMock` and use its names (the Sourcery convention is `<method><Label>Closure` / `CallsCount`).

- [ ] **Step 6: Commit**

```bash
git add ElementXWatch UnitTests
git commit -m "Add the QR login screen and authentication flow

Walks the user through showing the QR code, entering the phone's check
code with the Digital Crown and approving on the phone. Cancelling or
retrying starts a clean attempt, and updates from abandoned attempts
are ignored.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

## Phase D — Chats, timeline and app lifecycle

### Task 15: Chats list, settings and the user-session flow

**Files:**
- Create: `ElementXWatch/Sources/Other/SwiftUI/MediaLoader.swift`
- Create: `ElementXWatch/Sources/Other/SwiftUI/AvatarView.swift`
- Create: `ElementXWatch/Sources/Screens/ChatsScreen/{ChatsScreenModels,ChatsScreenViewModelProtocol,ChatsScreenViewModel,ChatsScreenCoordinator}.swift`, `…/ChatsScreen/View/{ChatsScreen,RoomRow}.swift`
- Create: `ElementXWatch/Sources/Screens/SettingsScreen/{SettingsScreenModels,SettingsScreenViewModelProtocol,SettingsScreenViewModel,SettingsScreenCoordinator}.swift`, `…/SettingsScreen/View/SettingsScreen.swift`
- Create: `ElementXWatch/Sources/FlowCoordinators/UserSessionFlowCoordinator.swift`
- Modify: `ElementXWatch/Sources/Other/WatchStrings.swift`
- Test: `UnitTests/Sources/ChatsScreenViewModelTests.swift`, `UnitTests/Sources/SettingsScreenViewModelTests.swift`

**Interfaces:**
- Consumes: `ClientProxyProtocol`, `SyncState`, `SessionVerification`, `MediaSourceProxy` (Task 12); `RoomSummary`, `RoomSummaryProviderProtocol` (Task 11).
- Produces:
  ```swift
  struct MediaLoader { let loadThumbnail: (MediaSourceProxy, Int, Int) async -> Data? }
  extension EnvironmentValues { var mediaLoader: MediaLoader }   // default returns nil
  struct AvatarView: View { init(name: String, mxcURL: URL?, size: CGFloat) }
  enum ChatsScreenViewModelAction { case openRoom(RoomSummary), openSettings }
  struct ChatsScreenViewState: BindableState { var rooms: [RoomSummary]; var syncState: SyncState; var isLoading: Bool }
  enum ChatsScreenViewAction { case selectRoom(String), openSettings }
  final class ChatsScreenViewModel { init(clientProxy: ClientProxyProtocol); var actionsPublisher }
  enum SettingsScreenViewModelAction { case signOut }
  struct SettingsScreenViewState: BindableState { let userID: String; var displayName: String?; var verification: SessionVerification; var bindings: SettingsScreenBindings }
  struct SettingsScreenBindings { var isConfirmingSignOut: Bool }
  enum SettingsScreenViewAction { case signOut, confirmSignOut }
  final class SettingsScreenViewModel { init(clientProxy: ClientProxyProtocol); var actionsPublisher }
  enum UserSessionRoute: Hashable { case chat(roomID: String, name: String, isDirect: Bool), settings }
  enum UserSessionFlowCoordinatorAction { case signOut }
  final class UserSessionFlowCoordinator: CoordinatorProtocol { init(clientProxy: ClientProxyProtocol); var actionsPublisher: AnyPublisher<UserSessionFlowCoordinatorAction, Never> }
  ```

- [ ] **Step 1: Write the failing tests**

`UnitTests/Sources/ChatsScreenViewModelTests.swift`:

```swift
import Combine
@testable import ElementXWatch
import Foundation
import Testing

@Suite
struct ChatsScreenViewModelTests {
    @Test
    func roomsAndSyncStateAreShown() async throws {
        let setup = Setup()
        let viewModel = ChatsScreenViewModel(clientProxy: setup.clientProxy)
        #expect(viewModel.context.viewState.isLoading)

        setup.rooms.send([.fixture(id: "!a:x", name: "Alice")])
        setup.syncState.send(.offline)

        try await waitUntil { viewModel.context.viewState.rooms.map(\.id) == ["!a:x"] }
        #expect(!viewModel.context.viewState.isLoading)
        #expect(viewModel.context.viewState.syncState == .offline)
    }

    @Test
    func selectingARoomOpensIt() async throws {
        let setup = Setup()
        let viewModel = ChatsScreenViewModel(clientProxy: setup.clientProxy)
        setup.rooms.send([.fixture(id: "!a:x", name: "Alice")])
        try await waitUntil { !viewModel.context.viewState.rooms.isEmpty }
        var opened: RoomSummary?
        let cancellable = viewModel.actionsPublisher.sink { if case .openRoom(let room) = $0 { opened = room } }

        viewModel.context.send(viewAction: .selectRoom("!a:x"))

        #expect(opened?.name == "Alice")
        cancellable.cancel()
    }

    @Test
    func settingsCanBeOpened() {
        let viewModel = ChatsScreenViewModel(clientProxy: Setup().clientProxy)
        var openedSettings = false
        let cancellable = viewModel.actionsPublisher.sink { if case .openSettings = $0 { openedSettings = true } }

        viewModel.context.send(viewAction: .openSettings)

        #expect(openedSettings)
        cancellable.cancel()
    }
}

// MARK: - Helpers

struct Setup {
    let rooms = CurrentValueSubject<[RoomSummary], Never>([])
    let syncState = CurrentValueSubject<SyncState, Never>(.running)
    let verification = CurrentValueSubject<SessionVerification, Never>(.verified)
    let actions = PassthroughSubject<ClientProxyAction, Never>()
    let clientProxy = ClientProxyMock()

    init() {
        let provider = RoomSummaryProviderMock()
        provider.roomsPublisher = rooms.eraseToAnyPublisher()
        clientProxy.roomSummaryProvider = provider
        clientProxy.syncStatePublisher = syncState.eraseToAnyPublisher()
        clientProxy.verificationStatePublisher = verification.eraseToAnyPublisher()
        clientProxy.actionsPublisher = actions.eraseToAnyPublisher()
        clientProxy.userID = "@me:example.org"
        clientProxy.loadDisplayNameReturnValue = "Me"
    }
}

extension RoomSummary {
    static func fixture(id: String, name: String, isDirect: Bool = true, unreadCount: Int = 0) -> RoomSummary {
        RoomSummary(id: id, name: name, avatarURL: nil, isDirect: isDirect, lastMessage: "Hello", lastMessageDate: .now,
                    unreadCount: unreadCount, hasUnreadMentions: false, isMarkedUnread: false)
    }
}
```

`UnitTests/Sources/SettingsScreenViewModelTests.swift`:

```swift
import Combine
@testable import ElementXWatch
import Testing

@Suite
struct SettingsScreenViewModelTests {
    @Test
    func showsIdentityAndVerification() async throws {
        let setup = Setup()
        setup.verification.send(.unverified)
        let viewModel = SettingsScreenViewModel(clientProxy: setup.clientProxy)

        try await waitUntil { viewModel.context.viewState.displayName == "Me" }
        #expect(viewModel.context.viewState.userID == "@me:example.org")
        #expect(viewModel.context.viewState.verification == .unverified)
    }

    @Test
    func signOutNeedsConfirmation() {
        let viewModel = SettingsScreenViewModel(clientProxy: Setup().clientProxy)
        var signedOut = false
        let cancellable = viewModel.actionsPublisher.sink { if case .signOut = $0 { signedOut = true } }

        viewModel.context.send(viewAction: .signOut)
        #expect(viewModel.context.viewState.bindings.isConfirmingSignOut)
        #expect(!signedOut)

        viewModel.context.send(viewAction: .confirmSignOut)
        #expect(signedOut)
        cancellable.cancel()
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the standard test command with `-only-testing:UnitTests/ChatsScreenViewModelTests -only-testing:UnitTests/SettingsScreenViewModelTests`.
Expected: build failure `cannot find 'ChatsScreenViewModel' in scope`.

- [ ] **Step 3: Implement shared UI pieces**

Add to `WatchStrings`:

```swift
    static let chats = "Chats"
    static let settings = "Settings"
    static let noChats = "No chats yet"
    static let offline = "Offline"
    static let connecting = "Connecting…"
    static let signOut = "Sign out"
    static let signOutConfirmation = "Sign out of Element X on this watch?"
    static let verified = "Verified session"
    static let unverified = "Unverified session"
    static let verificationUnknown = "Checking verification…"
```

`Other/SwiftUI/MediaLoader.swift`:

```swift
import Foundation
import SwiftUI

/// Loads media thumbnails for views without handing them the whole client.
struct MediaLoader {
    let loadThumbnail: (MediaSourceProxy, Int, Int) async -> Data?
}

extension EnvironmentValues {
    @Entry var mediaLoader = MediaLoader { _, _, _ in nil }
}
```

`Other/SwiftUI/AvatarView.swift`:

```swift
import MatrixRustSDK
import SwiftUI

/// Initials in a coloured circle, replaced by the thumbnail once it loads.
struct AvatarView: View {
    let name: String
    let mxcURL: URL?
    let size: CGFloat

    @Environment(\.mediaLoader) private var mediaLoader
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle().fill(Color.compound.bgAccentRest)
            Text(initials).font(.system(size: size * 0.45, weight: .semibold)).foregroundStyle(.white)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
        .task(id: mxcURL) { await loadImage() }
    }

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first(where: \.isLetter) }
        return letters.isEmpty ? "#" : String(letters).uppercased()
    }

    private func loadImage() async {
        guard let mxcURL, let source = try? MediaSource.fromUrl(url: mxcURL.absoluteString) else { return }
        let pixels = Int(size * displayScale)
        if let data = await mediaLoader.loadThumbnail(MediaSourceProxy(source: source), pixels, pixels) {
            image = UIImage(data: data)
        }
    }
}
```

- [ ] **Step 4: Implement the chats screen**

`ChatsScreenModels.swift`:

```swift
enum ChatsScreenViewModelAction {
    case openRoom(RoomSummary)
    case openSettings
}

struct ChatsScreenViewState: BindableState {
    var rooms: [RoomSummary] = []
    var syncState: SyncState = .idle
    var isLoading = true
}

enum ChatsScreenViewAction {
    case selectRoom(String)
    case openSettings
}
```

`ChatsScreenViewModelProtocol.swift`:

```swift
import Combine

protocol ChatsScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<ChatsScreenViewModelAction, Never> { get }
    var context: ChatsScreenViewModel.Context { get }
}
```

`ChatsScreenViewModel.swift`:

```swift
import Combine

typealias ChatsScreenViewModelType = StateStoreViewModelV2<ChatsScreenViewState, ChatsScreenViewAction>

final class ChatsScreenViewModel: ChatsScreenViewModelType, ChatsScreenViewModelProtocol {
    private let actionsSubject = PassthroughSubject<ChatsScreenViewModelAction, Never>()

    var actionsPublisher: AnyPublisher<ChatsScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(clientProxy: ClientProxyProtocol) {
        super.init(initialViewState: ChatsScreenViewState())

        clientProxy.roomSummaryProvider.roomsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rooms in
                self?.state.rooms = rooms
                self?.state.isLoading = false
            }
            .store(in: &cancellables)

        clientProxy.syncStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] syncState in self?.state.syncState = syncState }
            .store(in: &cancellables)
    }

    override func process(viewAction: ChatsScreenViewAction) {
        switch viewAction {
        case .selectRoom(let roomID):
            guard let room = state.rooms.first(where: { $0.id == roomID }) else { return }
            actionsSubject.send(.openRoom(room))
        case .openSettings:
            actionsSubject.send(.openSettings)
        }
    }
}
```

`RoomSummaryProvider` publishes nothing until its first real list (Task 11), so the screen shows "loading" until then without any special-casing here. `receive(on:)` always delivers asynchronously, which is why the test can still check `isLoading` immediately after `init`.

`ChatsScreenCoordinator.swift`:

```swift
import Combine
import SwiftUI

final class ChatsScreenCoordinator: CoordinatorProtocol {
    private let viewModel: ChatsScreenViewModel

    var actionsPublisher: AnyPublisher<ChatsScreenViewModelAction, Never> {
        viewModel.actionsPublisher
    }

    init(clientProxy: ClientProxyProtocol) {
        viewModel = ChatsScreenViewModel(clientProxy: clientProxy)
    }

    func toPresentable() -> AnyView {
        AnyView(ChatsScreen(context: viewModel.context))
    }
}
```

`View/RoomRow.swift`:

```swift
import SwiftUI

struct RoomRow: View {
    let room: RoomSummary

    var body: some View {
        HStack(spacing: 8) {
            AvatarView(name: room.name, mxcURL: room.avatarURL, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(room.name).font(.headline).lineLimit(1)
                    Spacer(minLength: 4)
                    if let date = room.lastMessageDate {
                        Text(date, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                            .font(.caption2)
                            .foregroundStyle(Color.compound.textSecondary)
                    }
                }
                HStack {
                    Text(room.lastMessage ?? " ")
                        .font(.footnote)
                        .foregroundStyle(Color.compound.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if room.hasUnread {
                        Circle()
                            .fill(room.hasUnreadMentions ? Color.compound.iconCriticalPrimary : Color.compound.iconAccentPrimary)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
```

`View/ChatsScreen.swift`:

```swift
import SwiftUI

struct ChatsScreen: View {
    @Bindable var context: ChatsScreenViewModel.Context

    var body: some View {
        List {
            if let banner {
                Text(banner).font(.footnote).foregroundStyle(Color.compound.textSecondary)
            }
            if context.viewState.isLoading {
                ProgressView()
            } else if context.viewState.rooms.isEmpty {
                Text(WatchStrings.noChats).foregroundStyle(Color.compound.textSecondary)
            } else {
                ForEach(context.viewState.rooms) { room in
                    Button { context.send(viewAction: .selectRoom(room.id)) } label: { RoomRow(room: room) }
                }
            }
        }
        .navigationTitle(WatchStrings.chats)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { context.send(viewAction: .openSettings) } label: { Image(compound: \.settings) }
                    .accessibilityLabel(WatchStrings.settings)
            }
        }
    }

    private var banner: String? {
        switch context.viewState.syncState {
        case .offline: WatchStrings.offline
        case .error: WatchStrings.connecting
        case .idle, .running: nil
        }
    }
}

// MARK: - Previews

struct ChatsScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { ChatsScreen(context: makeViewModel(rooms: rooms, syncState: .running).context) }
            .previewDisplayName("Rooms")
        NavigationStack { ChatsScreen(context: makeViewModel(rooms: rooms, syncState: .offline).context) }
            .previewDisplayName("Offline")
        NavigationStack { ChatsScreen(context: makeViewModel(rooms: [], syncState: .running).context) }
            .previewDisplayName("Empty")
        NavigationStack { ChatsScreen(context: makeViewModel(rooms: nil, syncState: .running).context) }
            .previewDisplayName("Loading")
    }

    static let rooms = [
        RoomSummary(id: "1", name: "Alice", avatarURL: nil, isDirect: true, lastMessage: "See you soon!", lastMessageDate: .now,
                    unreadCount: 2, hasUnreadMentions: false, isMarkedUnread: false),
        RoomSummary(id: "2", name: "Climbing crew", avatarURL: nil, isDirect: false, lastMessage: "Bob: Saturday?",
                    lastMessageDate: .now.addingTimeInterval(-3600), unreadCount: 1, hasUnreadMentions: true, isMarkedUnread: false)
    ]

    static func makeViewModel(rooms: [RoomSummary]?, syncState: SyncState) -> ChatsScreenViewModel {
        let viewModel = ChatsScreenViewModel(clientProxy: ClientProxyMock.preview)
        viewModel.state.rooms = rooms ?? []
        viewModel.state.isLoading = rooms == nil
        viewModel.state.syncState = syncState
        return viewModel
    }
}
```

Add a preview helper to the app target, `ElementXWatch/Sources/Mocks/ClientProxyMock+Preview.swift`:

```swift
import Combine

extension ClientProxyMock {
    static var preview: ClientProxyMock {
        let mock = ClientProxyMock()
        let provider = RoomSummaryProviderMock()
        provider.roomsPublisher = Just([]).eraseToAnyPublisher()
        mock.roomSummaryProvider = provider
        mock.syncStatePublisher = Just(.running).eraseToAnyPublisher()
        mock.verificationStatePublisher = Just(.verified).eraseToAnyPublisher()
        mock.actionsPublisher = Empty().eraseToAnyPublisher()
        mock.userID = "@alice:matrix.org"
        mock.loadDisplayNameReturnValue = "Alice"
        return mock
    }
}
```

- [ ] **Step 5: Implement the settings screen**

`SettingsScreenModels.swift`:

```swift
enum SettingsScreenViewModelAction {
    case signOut
}

struct SettingsScreenViewState: BindableState {
    let userID: String
    var displayName: String?
    var verification: SessionVerification = .unknown
    var bindings = SettingsScreenBindings()
}

struct SettingsScreenBindings {
    var isConfirmingSignOut = false
}

enum SettingsScreenViewAction {
    case signOut
    case confirmSignOut
}
```

`SettingsScreenViewModelProtocol.swift`:

```swift
import Combine

protocol SettingsScreenViewModelProtocol {
    var actionsPublisher: AnyPublisher<SettingsScreenViewModelAction, Never> { get }
    var context: SettingsScreenViewModel.Context { get }
}
```

`SettingsScreenViewModel.swift`:

```swift
import Combine

typealias SettingsScreenViewModelType = StateStoreViewModelV2<SettingsScreenViewState, SettingsScreenViewAction>

final class SettingsScreenViewModel: SettingsScreenViewModelType, SettingsScreenViewModelProtocol {
    private let actionsSubject = PassthroughSubject<SettingsScreenViewModelAction, Never>()

    var actionsPublisher: AnyPublisher<SettingsScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(clientProxy: ClientProxyProtocol) {
        super.init(initialViewState: SettingsScreenViewState(userID: clientProxy.userID))

        clientProxy.verificationStatePublisher
            .sink { [weak self] verification in self?.state.verification = verification }
            .store(in: &cancellables)

        Task { [weak self] in
            let displayName = await clientProxy.loadDisplayName()
            self?.state.displayName = displayName
        }
    }

    override func process(viewAction: SettingsScreenViewAction) {
        switch viewAction {
        case .signOut:
            state.bindings.isConfirmingSignOut = true
        case .confirmSignOut:
            state.bindings.isConfirmingSignOut = false
            actionsSubject.send(.signOut)
        }
    }
}
```

`SettingsScreenCoordinator.swift`:

```swift
import Combine
import SwiftUI

final class SettingsScreenCoordinator: CoordinatorProtocol {
    private let viewModel: SettingsScreenViewModel

    var actionsPublisher: AnyPublisher<SettingsScreenViewModelAction, Never> {
        viewModel.actionsPublisher
    }

    init(clientProxy: ClientProxyProtocol) {
        viewModel = SettingsScreenViewModel(clientProxy: clientProxy)
    }

    func toPresentable() -> AnyView {
        AnyView(SettingsScreen(context: viewModel.context))
    }
}
```

`View/SettingsScreen.swift`:

```swift
import SwiftUI

struct SettingsScreen: View {
    @Bindable var context: SettingsScreenViewModel.Context

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading) {
                    Text(context.viewState.displayName ?? context.viewState.userID).font(.headline)
                    Text(context.viewState.userID).font(.footnote).foregroundStyle(Color.compound.textSecondary)
                }
                Label(verificationText, systemImage: context.viewState.verification == .verified ? "checkmark.shield" : "exclamationmark.shield")
            }
            Section {
                Button(WatchStrings.signOut, role: .destructive) { context.send(viewAction: .signOut) }
            }
        }
        .navigationTitle(WatchStrings.settings)
        .confirmationDialog(WatchStrings.signOutConfirmation, isPresented: $context.isConfirmingSignOut) {
            Button(WatchStrings.signOut, role: .destructive) { context.send(viewAction: .confirmSignOut) }
            Button(WatchStrings.cancel, role: .cancel) { }
        }
    }

    private var verificationText: String {
        switch context.viewState.verification {
        case .verified: WatchStrings.verified
        case .unverified: WatchStrings.unverified
        case .unknown: WatchStrings.verificationUnknown
        }
    }
}

// MARK: - Previews

struct SettingsScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { SettingsScreen(context: SettingsScreenViewModel(clientProxy: ClientProxyMock.preview).context) }
            .previewDisplayName("Verified")
        NavigationStack { SettingsScreen(context: unverified.context) }
            .previewDisplayName("Unverified")
    }

    static var unverified: SettingsScreenViewModel {
        let viewModel = SettingsScreenViewModel(clientProxy: ClientProxyMock.preview)
        viewModel.state.verification = .unverified
        return viewModel
    }
}
```

- [ ] **Step 6: Implement the user-session flow**

`FlowCoordinators/UserSessionFlowCoordinator.swift`:

```swift
import Combine
import Observation
import SwiftUI

enum UserSessionRoute: Hashable {
    case chat(roomID: String, name: String, isDirect: Bool)
    case settings
}

enum UserSessionFlowCoordinatorAction {
    case signOut
}

/// The signed-in flow: Chats → Chat, and Settings, in one NavigationStack.
final class UserSessionFlowCoordinator: CoordinatorProtocol {
    @Observable final class Navigation {
        var path: [UserSessionRoute] = []
    }

    private let clientProxy: ClientProxyProtocol
    private let chatsCoordinator: ChatsScreenCoordinator
    private let navigation = Navigation()
    private let actionsSubject = PassthroughSubject<UserSessionFlowCoordinatorAction, Never>()
    private var childCoordinators: [UserSessionRoute: CoordinatorProtocol] = [:]
    private var cancellables = Set<AnyCancellable>()

    var actionsPublisher: AnyPublisher<UserSessionFlowCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(clientProxy: ClientProxyProtocol) {
        self.clientProxy = clientProxy
        chatsCoordinator = ChatsScreenCoordinator(clientProxy: clientProxy)
    }

    func start() {
        chatsCoordinator.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .openRoom(let room):
                    self?.navigation.path.append(.chat(roomID: room.id, name: room.name, isDirect: room.isDirect))
                case .openSettings:
                    self?.navigation.path.append(.settings)
                }
            }
            .store(in: &cancellables)
    }

    func toPresentable() -> AnyView {
        let clientProxy = clientProxy
        return AnyView(UserSessionFlowView(navigation: navigation,
                                           root: chatsCoordinator.toPresentable(),
                                           destination: { [weak self] route in self?.destination(for: route) ?? AnyView(EmptyView()) })
                .environment(\.mediaLoader, MediaLoader { source, width, height in
                    await clientProxy.loadThumbnail(for: source, width: width, height: height)
                }))
    }

    private func destination(for route: UserSessionRoute) -> AnyView {
        if let coordinator = childCoordinators[route] {
            return coordinator.toPresentable()
        }

        let coordinator: CoordinatorProtocol
        switch route {
        case .chat(_, let name, _):
            // Replaced by the chat screen in Task 17.
            coordinator = PlaceholderCoordinator(title: name)
        case .settings:
            let settings = SettingsScreenCoordinator(clientProxy: clientProxy)
            settings.actionsPublisher
                .sink { [weak self] action in
                    switch action {
                    case .signOut: self?.actionsSubject.send(.signOut)
                    }
                }
                .store(in: &cancellables)
            coordinator = settings
        }

        coordinator.start()
        childCoordinators[route] = coordinator
        return coordinator.toPresentable()
    }
}

private struct UserSessionFlowView: View {
    @Bindable var navigation: UserSessionFlowCoordinator.Navigation
    let root: AnyView
    let destination: (UserSessionRoute) -> AnyView

    var body: some View {
        NavigationStack(path: $navigation.path) {
            root.navigationDestination(for: UserSessionRoute.self) { route in destination(route) }
        }
    }
}

private final class PlaceholderCoordinator: CoordinatorProtocol {
    private let title: String

    init(title: String) {
        self.title = title
    }

    func toPresentable() -> AnyView {
        AnyView(Text(title))
    }
}
```

Child coordinators are cached per route so their view models survive re-renders. Popped routes are pruned in Task 17.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `xcodegen`, then the standard test command with `-only-testing:UnitTests/ChatsScreenViewModelTests -only-testing:UnitTests/SettingsScreenViewModelTests`.
Expected: 5 tests passed.

- [ ] **Step 8: Commit**

```bash
git add ElementXWatch UnitTests
git commit -m "Add the chats list, settings and signed-in navigation

The chats list shows DMs and groups with avatars, previews, unread dots
and an offline banner. Settings shows the account, its verification
state and sign out with confirmation.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

### Task 16: Timeline item models, content mapping and message formatting

**Files:**
- Create: `ElementXWatch/Sources/Services/Timeline/TimelineItem.swift`
- Create: `ElementXWatch/Sources/Services/Timeline/TimelineItemFactory.swift` (derived from iOS `Services/Timeline/TimelineItems/…` factory rules)
- Create: `ElementXWatch/Sources/Services/Timeline/MessageFormatter.swift`
- Modify: `ElementXWatch/Sources/Other/WatchStrings.swift`
- Test: `UnitTests/Sources/TimelineItemFactoryTests.swift`, `UnitTests/Sources/MessageFormatterTests.swift`

**Interfaces:**
- Consumes: `MediaSourceProxy` (Task 12), `RoomSummaryPreview.text(for:)`, `RoomSummaryPreview.displayName(from:)` (Task 11).
- Produces:
  ```swift
  struct TimelineItem: Identifiable, Equatable { let id: String; let kind: Kind
      enum Kind: Equatable { case event(EventItem), dateDivider(Date), readMarker, timelineStart, hidden }
      var isVisible: Bool }
  struct EventItem: Equatable { let itemID: EventOrTransactionId; let eventID: String?; let senderID: String; let senderName: String; let isOwn: Bool
      let date: Date; let body: TimelineItemBody; let replyTo: ReplyPreview?; let reactions: [ReactionSummary]; let isEdited: Bool; let sendState: SendState; let canBeRepliedTo: Bool }
  enum TimelineItemBody: Equatable { case text(AttributedString), emote(AttributedString), notice(AttributedString), image(ImageBody), redacted, undecryptable, unsupported(String) }
  struct ImageBody: Equatable { let caption: String?; let source: MediaSourceProxy; let thumbnailSource: MediaSourceProxy?; let aspectRatio: Double? }
  struct ReplyPreview: Equatable { let senderName: String; let text: String }
  struct ReactionSummary: Equatable, Identifiable { let key: String; let count: Int; let isHighlighted: Bool; var id: String }
  enum SendState: Equatable { case sent, sending, failed }
  enum TimelineItemFactory {
      static func makeItem(from item: MatrixRustSDK.TimelineItem, ownUserID: String) -> TimelineItem
      static func body(for content: TimelineItemContent) -> TimelineItemBody?
      static func isEdited(_ content: TimelineItemContent) -> Bool
      static func reactions(from reactions: [Reaction], ownUserID: String) -> [ReactionSummary]
      static func sendState(from state: EventSendState?) -> SendState }
  enum MessageFormatter { static func attributedString(from body: String) -> AttributedString }
  ```

- [ ] **Step 1: Write the failing tests**

`UnitTests/Sources/TimelineItemFactoryTests.swift`:

```swift
@testable import ElementXWatch
import Foundation
import MatrixRustSDK
import Testing

struct TimelineItemFactoryTests {
    @Test
    func textLikeMessagesMap() {
        #expect(TimelineItemFactory.body(for: textContent("hi")) == .text(AttributedString("hi")))
        #expect(TimelineItemFactory.body(for: messageContent(.emote(content: EmoteMessageContent(body: "waves", formatted: nil)))) == .emote(AttributedString("waves")))
        #expect(TimelineItemFactory.body(for: messageContent(.notice(content: NoticeMessageContent(body: "bot", formatted: nil)))) == .notice(AttributedString("bot")))
    }

    @Test
    func specialStatesMap() {
        #expect(TimelineItemFactory.body(for: msgLike(.redacted)) == .redacted)
        #expect(TimelineItemFactory.body(for: msgLike(.unableToDecrypt(msg: .unknown))) == .undecryptable)
    }

    @Test
    func imagesMap() throws {
        let source = try MediaSource.fromUrl(url: "mxc://example.org/abc")
        let image = ImageMessageContent(filename: "a.jpg", caption: "Look", formattedCaption: nil, source: source,
                                        info: ImageInfo(height: 100, width: 200, mimetype: "image/jpeg", size: nil, thumbnailInfo: nil,
                                                        thumbnailSource: nil, blurhash: nil, isAnimated: false))

        let body = TimelineItemFactory.body(for: messageContent(.image(content: image)))

        guard case .image(let imageBody) = body else { Issue.record("Expected an image"); return }
        #expect(imageBody.caption == "Look")
        #expect(imageBody.source.url == "mxc://example.org/abc")
        #expect(imageBody.aspectRatio == 2)
    }

    @Test
    func unsupportedMessagesShowAPlaceholder() {
        #expect(TimelineItemFactory.body(for: msgLike(.poll(question: "Lunch?", kind: .undisclosed, maxSelections: 1, answers: [], votes: [:], endTime: nil, hasBeenEdited: false)))
            == .unsupported("📊 Lunch?"))
    }

    @Test
    func stateEventsAreHidden() {
        #expect(TimelineItemFactory.body(for: .profileChange(displayName: "B", prevDisplayName: "A", avatarUrl: nil, prevAvatarUrl: nil)) == nil)
    }

    @Test
    func editsAreDetected() {
        #expect(TimelineItemFactory.isEdited(textContent("x", isEdited: true)))
        #expect(!TimelineItemFactory.isEdited(textContent("x")))
    }

    @Test
    func reactionsAreCountedAndHighlightedForOwn() {
        let reactions = [
            Reaction(key: "👍", senders: [.init(senderId: "@me:x", timestamp: 1, sendState: nil), .init(senderId: "@bob:x", timestamp: 2, sendState: nil)]),
            Reaction(key: "❤️", senders: [.init(senderId: "@bob:x", timestamp: 3, sendState: nil)])
        ]

        let summaries = TimelineItemFactory.reactions(from: reactions, ownUserID: "@me:x")

        #expect(summaries == [.init(key: "👍", count: 2, isHighlighted: true), .init(key: "❤️", count: 1, isHighlighted: false)])
    }

    @Test
    func sendStatesMap() {
        #expect(TimelineItemFactory.sendState(from: nil) == .sent)
        #expect(TimelineItemFactory.sendState(from: .notSentYet(progress: nil)) == .sending)
        #expect(TimelineItemFactory.sendState(from: .sent(eventId: "$e")) == .sent)
    }
}
```

`UnitTests/Sources/MessageFormatterTests.swift`:

```swift
@testable import ElementXWatch
import Foundation
import Testing

struct MessageFormatterTests {
    @Test
    func plainTextIsUnchanged() {
        #expect(String(MessageFormatter.attributedString(from: "hello there").characters) == "hello there")
    }

    @Test
    func markdownEmphasisIsRendered() {
        let result = MessageFormatter.attributedString(from: "a **bold** move")
        #expect(String(result.characters) == "a bold move")
        #expect(result.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    }

    @Test
    func bareURLsBecomeLinks() {
        let result = MessageFormatter.attributedString(from: "see https://element.io now")
        #expect(result.runs.contains { $0.link == URL(string: "https://element.io") })
    }

    @Test
    func newlinesArePreserved() {
        #expect(String(MessageFormatter.attributedString(from: "one\ntwo").characters) == "one\ntwo")
    }
}
```

If the generated `ImageInfo`, `Reaction`, `ReactionSenderData` or `PollKind` initialisers differ from these, match `Packages/MatrixRustSDK/Sources/MatrixRustSDK/matrix_sdk_ffi.swift`. `PollKind` has `.undisclosed` and `.disclosed`.

- [ ] **Step 2: Run the tests to verify they fail**

Run the standard test command with `-only-testing:UnitTests/TimelineItemFactoryTests -only-testing:UnitTests/MessageFormatterTests`.
Expected: build failure `cannot find 'TimelineItemFactory' in scope`.

- [ ] **Step 3: Implement**

Add to `WatchStrings`:

```swift
    static let unsupportedMessage = "Unsupported message"
```

`Services/Timeline/TimelineItem.swift`:

```swift
import Foundation
import MatrixRustSDK

/// One entry per SDK timeline item (hidden ones included) so SDK diffs map 1:1 by index.
struct TimelineItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case event(EventItem)
        case dateDivider(Date)
        case readMarker
        case timelineStart
        /// State events and other items the watch doesn't show.
        case hidden
    }

    let id: String
    let kind: Kind

    var isVisible: Bool {
        switch kind {
        case .event, .dateDivider: true
        case .readMarker, .timelineStart, .hidden: false
        }
    }
}

struct EventItem: Equatable {
    let itemID: EventOrTransactionId
    let eventID: String?
    let senderID: String
    let senderName: String
    let isOwn: Bool
    let date: Date
    let body: TimelineItemBody
    let replyTo: ReplyPreview?
    let reactions: [ReactionSummary]
    let isEdited: Bool
    let sendState: SendState
    let canBeRepliedTo: Bool
}

enum TimelineItemBody: Equatable {
    case text(AttributedString)
    case emote(AttributedString)
    case notice(AttributedString)
    case image(ImageBody)
    case redacted
    case undecryptable
    case unsupported(String)
}

struct ImageBody: Equatable {
    let caption: String?
    let source: MediaSourceProxy
    let thumbnailSource: MediaSourceProxy?
    /// Width divided by height, when known.
    let aspectRatio: Double?
}

struct ReplyPreview: Equatable {
    let senderName: String
    let text: String
}

struct ReactionSummary: Equatable, Identifiable {
    let key: String
    let count: Int
    let isHighlighted: Bool

    var id: String { key }
}

enum SendState: Equatable {
    case sent
    case sending
    case failed
}
```

`Services/Timeline/MessageFormatter.swift`:

```swift
import Foundation

/// Renders message bodies: inline Markdown (bold, italic, code, links) plus auto-linked URLs.
enum MessageFormatter {
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func attributedString(from body: String) -> AttributedString {
        var result = (try? AttributedString(markdown: body, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(body)
        addLinks(to: &result)
        return result
    }

    private static func addLinks(to string: inout AttributedString) {
        guard let linkDetector else { return }
        let plain = String(string.characters)
        for match in linkDetector.matches(in: plain, range: NSRange(plain.startIndex..., in: plain)) {
            guard let url = match.url,
                  let stringRange = Range(match.range, in: plain),
                  let range = Range(stringRange, in: string),
                  string[range].link == nil else { continue }
            string[range].link = url
        }
    }
}
```

`Services/Timeline/TimelineItemFactory.swift`:

```swift
import Foundation
import MatrixRustSDK

/// Maps SDK timeline items to the watch's display models.
enum TimelineItemFactory {
    static func makeItem(from item: MatrixRustSDK.TimelineItem, ownUserID: String) -> TimelineItem {
        let id = item.uniqueId().id

        if let event = item.asEvent() {
            guard let body = body(for: event.content) else { return TimelineItem(id: id, kind: .hidden) }
            return TimelineItem(id: id, kind: .event(makeEventItem(event, body: body, ownUserID: ownUserID)))
        }

        switch item.asVirtual() {
        case .dateDivider(let timestamp):
            return TimelineItem(id: id, kind: .dateDivider(Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)))
        case .readMarker:
            return TimelineItem(id: id, kind: .readMarker)
        case .timelineStart:
            return TimelineItem(id: id, kind: .timelineStart)
        case nil:
            return TimelineItem(id: id, kind: .hidden)
        }
    }

    static func body(for content: TimelineItemContent) -> TimelineItemBody? {
        guard case .msgLike(let msgLike) = content else { return nil }

        switch msgLike.kind {
        case .message(let message):
            switch message.msgType {
            case .text(let text):
                return .text(MessageFormatter.attributedString(from: text.body))
            case .emote(let emote):
                return .emote(MessageFormatter.attributedString(from: emote.body))
            case .notice(let notice):
                return .notice(MessageFormatter.attributedString(from: notice.body))
            case .image(let image):
                return .image(ImageBody(caption: image.caption,
                                        source: MediaSourceProxy(source: image.source),
                                        thumbnailSource: image.info?.thumbnailSource.map(MediaSourceProxy.init),
                                        aspectRatio: aspectRatio(width: image.info?.width, height: image.info?.height)))
            default:
                return .unsupported(RoomSummaryPreview.text(for: content) ?? WatchStrings.unsupportedMessage)
            }
        case .sticker(_, let info, let source):
            return .image(ImageBody(caption: nil,
                                    source: MediaSourceProxy(source: source),
                                    thumbnailSource: info.thumbnailSource.map(MediaSourceProxy.init),
                                    aspectRatio: aspectRatio(width: info.width, height: info.height)))
        case .redacted:
            return .redacted
        case .unableToDecrypt:
            return .undecryptable
        case .poll, .liveLocation:
            return .unsupported(RoomSummaryPreview.text(for: content) ?? WatchStrings.unsupportedMessage)
        case .other:
            return nil
        }
    }

    static func isEdited(_ content: TimelineItemContent) -> Bool {
        guard case .msgLike(let msgLike) = content, case .message(let message) = msgLike.kind else { return false }
        return message.isEdited
    }

    static func reactions(from reactions: [Reaction], ownUserID: String) -> [ReactionSummary] {
        reactions.map { reaction in
            ReactionSummary(key: reaction.key,
                            count: reaction.senders.count,
                            isHighlighted: reaction.senders.contains { $0.senderId == ownUserID })
        }
    }

    static func sendState(from state: EventSendState?) -> SendState {
        switch state {
        case nil, .sent: .sent
        case .notSentYet: .sending
        case .sendingFailed: .failed
        }
    }

    private static func makeEventItem(_ event: EventTimelineItem, body: TimelineItemBody, ownUserID: String) -> EventItem {
        let eventID: String? = if case .eventId(let id) = event.eventOrTransactionId { id } else { nil }
        return EventItem(itemID: event.eventOrTransactionId,
                         eventID: eventID,
                         senderID: event.sender,
                         senderName: RoomSummaryPreview.displayName(from: event.senderProfile) ?? event.sender,
                         isOwn: event.isOwn,
                         date: Date(timeIntervalSince1970: TimeInterval(event.timestamp) / 1000),
                         body: body,
                         replyTo: replyPreview(for: event.content),
                         reactions: reactions(from: event.reactions, ownUserID: ownUserID),
                         isEdited: isEdited(event.content),
                         sendState: sendState(from: event.localSendState),
                         canBeRepliedTo: event.canBeRepliedTo)
    }

    private static func replyPreview(for content: TimelineItemContent) -> ReplyPreview? {
        guard case .msgLike(let msgLike) = content, let inReplyTo = msgLike.inReplyTo else { return nil }
        guard case .ready(let repliedContent, let sender, let senderProfile, _, _) = inReplyTo.event() else {
            return ReplyPreview(senderName: "", text: "…")
        }
        return ReplyPreview(senderName: RoomSummaryPreview.displayName(from: senderProfile) ?? sender,
                            text: RoomSummaryPreview.text(for: repliedContent) ?? WatchStrings.unsupportedMessage)
    }

    private static func aspectRatio(width: UInt64?, height: UInt64?) -> Double? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return Double(width) / Double(height)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodegen`, then the standard test command with `-only-testing:UnitTests/TimelineItemFactoryTests -only-testing:UnitTests/MessageFormatterTests`.
Expected: 12 tests passed.

- [ ] **Step 5: Record provenance and commit**

Append to `SHARED_FROM_IOS.md`:

```markdown
| `ElementXWatch/Sources/Services/Timeline/TimelineItemFactory.swift` | `ElementX/Sources/Services/Timeline/TimelineItems/RoomTimelineItemFactory.swift` (content rules) | Text, emote, notice, image, sticker, redacted and UTD only; everything else is a placeholder or hidden. Markdown instead of HTML rendering. |
```

```bash
git add ElementXWatch UnitTests SHARED_FROM_IOS.md
git commit -m "Add timeline display models and content mapping

Maps SDK timeline items one-to-one (hidden ones included, so index
diffs stay valid) to watch display models covering text, emotes,
notices, images, replies, reactions, edits, redactions, UTDs and send
state. Bodies render inline Markdown with auto-linked URLs.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

### Task 17: Timeline proxy and the chat screen

**Files:**
- Create: `ElementXWatch/Sources/Services/Timeline/TimelineProxy.swift` (derived from iOS `Services/Timeline/TimelineProxy.swift`)
- Modify: `ElementXWatch/Sources/Services/Client/ClientProxyProtocol.swift`, `ClientProxy.swift` (add `timelineProxy(for:)`)
- Create: `ElementXWatch/Sources/Screens/ChatScreen/{ChatScreenModels,ChatScreenViewModelProtocol,ChatScreenViewModel,ChatScreenCoordinator}.swift`
- Create: `ElementXWatch/Sources/Screens/ChatScreen/View/{ChatScreen,MessageBubble,ReactionsBar,ImageThumbnail,MessageActionsSheet}.swift`
- Modify: `ElementXWatch/Sources/FlowCoordinators/UserSessionFlowCoordinator.swift` (real chat destination, prune popped routes)
- Modify: `ElementXWatch/Sources/Mocks/ClientProxyMock+Preview.swift`, `ElementXWatch/Sources/Other/WatchStrings.swift`
- Test: `UnitTests/Sources/ChatScreenViewModelTests.swift`

**Interfaces:**
- Consumes: `TimelineItem`, `EventItem`, `TimelineItemFactory` (Task 16); `ListDiff`, `SDKListener` (Task 7); `MediaLoader`, `AvatarView` (Task 15).
- Produces:
  ```swift
  enum TimelineProxyError: Error, Equatable { case sdkError(String) }
  // sourcery: AutoMockable
  protocol TimelineProxyProtocol: AnyObject {
      var itemsPublisher: AnyPublisher<[TimelineItem], Never> { get }
      func subscribe() async
      func paginateBackwards() async -> Result<Bool, TimelineProxyError>   // true once the start is reached
      func send(message: String, inReplyTo eventID: String?) async -> Result<Void, TimelineProxyError>
      func toggleReaction(_ key: String, to itemID: EventOrTransactionId) async -> Result<Void, TimelineProxyError>
      func retrySend(_ itemID: EventOrTransactionId) async -> Result<Void, TimelineProxyError>
      func markAsRead() async
  }
  final class TimelineProxy: TimelineProxyProtocol { init(timeline: Timeline, ownUserID: String) }
  // ClientProxyProtocol gains: func timelineProxy(for roomID: String) async -> TimelineProxyProtocol?
  struct ChatScreenViewState: BindableState { let roomName: String; let showsSenderNames: Bool; var items: [TimelineItem]; var isPaginating: Bool
      var reachedStart: Bool; var replyingTo: EventItem?; var bindings: ChatScreenBindings }
  struct ChatScreenBindings { var actionsItem: EventItem?; var errorMessage: String? }
  enum ChatScreenViewAction { case appear, paginateBackwards, send(String), showActions(EventItem), reply(EventItem), cancelReply, react(key: String, item: EventItem), retry(EventItem), dismissError }
  final class ChatScreenViewModel { init(roomName: String, isDirect: Bool, timelineProxy: TimelineProxyProtocol) }
  final class ChatScreenCoordinator: CoordinatorProtocol { init(roomName: String, isDirect: Bool, timelineProxy: TimelineProxyProtocol) }
  ```

- [ ] **Step 1: Write the failing tests**

`UnitTests/Sources/ChatScreenViewModelTests.swift`:

```swift
import Combine
@testable import ElementXWatch
import Foundation
import MatrixRustSDK
import Testing

@Suite
struct ChatScreenViewModelTests {
    @Test
    func appearSubscribesMarksReadAndShowsVisibleItems() async throws {
        let (viewModel, proxy, items) = makeViewModel()

        viewModel.context.send(viewAction: .appear)
        items.send([.event("1", body: "Hi"), TimelineItem(id: "h", kind: .hidden), .event("2", body: "There")])

        try await waitUntil { viewModel.context.viewState.items.map(\.id) == ["1", "2"] }
        #expect(proxy.subscribeCallsCount == 1)
        try await waitUntil { proxy.markAsReadCallsCount >= 1 }
    }

    @Test
    func sendTrimsAndRepliesToTheSelectedMessage() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        proxy.sendMessageInReplyToReturnValue = .success(())
        let target = EventItem.fixture(eventID: "$target")

        viewModel.context.send(viewAction: .reply(target))
        viewModel.context.send(viewAction: .send("  On my way  "))

        try await waitUntil { proxy.sendMessageInReplyToCallsCount == 1 }
        #expect(proxy.sendMessageInReplyToReceivedArguments?.message == "On my way")
        #expect(proxy.sendMessageInReplyToReceivedArguments?.eventID == "$target")
        #expect(viewModel.context.viewState.replyingTo == nil)
    }

    @Test
    func blankMessagesAreIgnored() async {
        let (viewModel, proxy, _) = makeViewModel()
        viewModel.context.send(viewAction: .send("   \n "))
        for _ in 0..<10 { await Task.yield() }
        #expect(proxy.sendMessageInReplyToCallsCount == 0)
    }

    @Test
    func sendFailuresAreShown() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        proxy.sendMessageInReplyToReturnValue = .failure(.sdkError("offline"))

        viewModel.context.send(viewAction: .send("Hello"))

        try await waitUntil { viewModel.context.viewState.bindings.errorMessage == WatchStrings.sendFailed }
    }

    @Test
    func failedMessagesCanBeRetried() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        proxy.retrySendReturnValue = .failure(.sdkError("still offline"))
        let failed = EventItem.fixture(eventID: nil, sendState: .failed)

        viewModel.context.send(viewAction: .retry(failed))

        try await waitUntil { proxy.retrySendCallsCount == 1 }
        #expect(proxy.retrySendReceivedItemID == failed.itemID)
        try await waitUntil { viewModel.context.viewState.bindings.errorMessage == WatchStrings.sendFailed }
    }

    @Test
    func reactingTogglesTheReactionAndClosesTheSheet() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        proxy.toggleReactionToReturnValue = .success(())
        let item = EventItem.fixture(eventID: "$e")
        viewModel.context.send(viewAction: .showActions(item))
        #expect(viewModel.context.viewState.bindings.actionsItem == item)

        viewModel.context.send(viewAction: .react(key: "👍", item: item))

        #expect(viewModel.context.viewState.bindings.actionsItem == nil)
        try await waitUntil { proxy.toggleReactionToCallsCount == 1 }
        #expect(proxy.toggleReactionToReceivedArguments?.key == "👍")
    }

    @Test
    func paginationStopsAtTheStart() async throws {
        let (viewModel, proxy, _) = makeViewModel()
        proxy.paginateBackwardsReturnValue = .success(true)

        viewModel.context.send(viewAction: .paginateBackwards)
        try await waitUntil { viewModel.context.viewState.reachedStart }
        viewModel.context.send(viewAction: .paginateBackwards)
        for _ in 0..<10 { await Task.yield() }

        #expect(proxy.paginateBackwardsCallsCount == 1)
        #expect(!viewModel.context.viewState.isPaginating)
    }

    // MARK: - Helpers

    private func makeViewModel() -> (ChatScreenViewModel, TimelineProxyProtocolMock, PassthroughSubject<[TimelineItem], Never>) {
        let items = PassthroughSubject<[TimelineItem], Never>()
        let proxy = TimelineProxyProtocolMock()
        proxy.itemsPublisher = items.eraseToAnyPublisher()
        proxy.paginateBackwardsReturnValue = .success(false)
        let viewModel = ChatScreenViewModel(roomName: "Alice", isDirect: true, timelineProxy: proxy)
        return (viewModel, proxy, items)
    }
}

extension EventItem {
    static func fixture(eventID: String?, body: String = "Hello", sendState: SendState = .sent, isOwn: Bool = false) -> EventItem {
        EventItem(itemID: eventID.map { .eventId(eventId: $0) } ?? .transactionId(transactionId: "txn"),
                  eventID: eventID,
                  senderID: "@bob:example.org",
                  senderName: "Bob",
                  isOwn: isOwn,
                  date: Date(timeIntervalSince1970: 1_700_000_000),
                  body: .text(AttributedString(body)),
                  replyTo: nil,
                  reactions: [],
                  isEdited: false,
                  sendState: sendState,
                  canBeRepliedTo: true)
    }
}

extension TimelineItem {
    static func event(_ id: String, body: String, isOwn: Bool = false) -> TimelineItem {
        TimelineItem(id: id, kind: .event(.fixture(eventID: "$\(id)", body: body, isOwn: isOwn)))
    }
}
```

Sourcery names for these mocks: `sendMessageInReplyTo…` for `send(message:inReplyTo:)`, `toggleReactionTo…` for `toggleReaction(_:to:)`, `retrySend…` for `retrySend(_:)` (single argument: `retrySendReceivedItemID`), `paginateBackwards…`, `markAsRead…` and `subscribe…`. If a generated name differs, use the one in `GeneratedMocks.swift`.

- [ ] **Step 2: Run the tests to verify they fail**

Run the standard test command with `-only-testing:UnitTests/ChatScreenViewModelTests`.
Expected: build failure `cannot find 'ChatScreenViewModel' in scope`.

- [ ] **Step 3: Implement the timeline proxy**

`Services/Timeline/TimelineProxy.swift`:

```swift
import Combine
import MatrixRustSDK

enum TimelineProxyError: Error, Equatable {
    case sdkError(String)
}

// sourcery: AutoMockable
protocol TimelineProxyProtocol: AnyObject {
    var itemsPublisher: AnyPublisher<[TimelineItem], Never> { get }

    func subscribe() async
    /// Loads older messages. Succeeds with `true` once the start of the room is reached.
    func paginateBackwards() async -> Result<Bool, TimelineProxyError>
    func send(message: String, inReplyTo eventID: String?) async -> Result<Void, TimelineProxyError>
    func toggleReaction(_ key: String, to itemID: EventOrTransactionId) async -> Result<Void, TimelineProxyError>
    func retrySend(_ itemID: EventOrTransactionId) async -> Result<Void, TimelineProxyError>
    func markAsRead() async
}

final class TimelineProxy: TimelineProxyProtocol {
    private static let paginationSize: UInt16 = 20

    private let timeline: Timeline
    private let ownUserID: String
    private let itemsSubject = CurrentValueSubject<[TimelineItem], Never>([])
    private var items: [TimelineItem] = []
    private var listenerHandle: TaskHandle?

    var itemsPublisher: AnyPublisher<[TimelineItem], Never> {
        itemsSubject.eraseToAnyPublisher()
    }

    init(timeline: Timeline, ownUserID: String) {
        self.timeline = timeline
        self.ownUserID = ownUserID
    }

    deinit {
        listenerHandle?.cancel()
    }

    func subscribe() async {
        guard listenerHandle == nil else { return }
        let ownUserID = ownUserID
        listenerHandle = await timeline.addListener(listener: SDKListener<[TimelineDiff]>.onMainActor { [weak self] diffs in
            guard let self else { return }
            for diff in diffs {
                items.apply(ListDiff(diff) { TimelineItemFactory.makeItem(from: $0, ownUserID: ownUserID) })
            }
            itemsSubject.send(items)
        })
    }

    func paginateBackwards() async -> Result<Bool, TimelineProxyError> {
        do {
            return try await .success(timeline.paginateBackwards(numEvents: Self.paginationSize))
        } catch {
            MXLog.error("Back-pagination failed: \(error)")
            return .failure(.sdkError(error.localizedDescription))
        }
    }

    func send(message: String, inReplyTo eventID: String?) async -> Result<Void, TimelineProxyError> {
        let content = messageEventContentFromMarkdown(md: message)
        do {
            if let eventID {
                _ = try await timeline.sendReply(msg: content, eventId: eventID)
            } else {
                _ = try await timeline.send(msg: content)
            }
            return .success(())
        } catch {
            MXLog.error("Sending a message failed: \(error)")
            return .failure(.sdkError(error.localizedDescription))
        }
    }

    func toggleReaction(_ key: String, to itemID: EventOrTransactionId) async -> Result<Void, TimelineProxyError> {
        do {
            _ = try await timeline.toggleReaction(itemId: itemID, key: key)
            return .success(())
        } catch {
            MXLog.error("Toggling a reaction failed: \(error)")
            return .failure(.sdkError(error.localizedDescription))
        }
    }

    func retrySend(_ itemID: EventOrTransactionId) async -> Result<Void, TimelineProxyError> {
        do {
            _ = try await timeline.retrySend(itemId: itemID, target: .event)
            return .success(())
        } catch {
            MXLog.error("Retrying a send failed: \(error)")
            return .failure(.sdkError(error.localizedDescription))
        }
    }

    func markAsRead() async {
        do {
            try await timeline.markAsRead(receiptType: .read)
        } catch {
            MXLog.error("Marking as read failed: \(error)")
        }
    }
}
```

Add to `ClientProxyProtocol`:

```swift
    func timelineProxy(for roomID: String) async -> TimelineProxyProtocol?
```

and to `ClientProxy`:

```swift
    func timelineProxy(for roomID: String) async -> TimelineProxyProtocol? {
        do {
            let roomListService = syncService.roomListService()
            // Subscribing gives the room full sliding-sync state while it's open.
            try await roomListService.setRoomSubscriptions(roomIds: [roomID])
            let room = try roomListService.room(roomId: roomID)
            return try await TimelineProxy(timeline: room.timeline(), ownUserID: userID)
        } catch {
            MXLog.error("Failed opening the timeline for \(roomID): \(error)")
            return nil
        }
    }
```

In `ClientProxyMock+Preview.swift`, add `mock.timelineProxyForReturnValue = nil` (the Sourcery name for `timelineProxy(for:)`) inside `preview`.

- [ ] **Step 4: Implement the chat screen view model and coordinator**

Add to `WatchStrings`:

```swift
    static let reply = "Reply"
    static let replyingTo = "Replying to"
    static let sendFailed = "Couldn't send. Tap the message to retry."
    static let failedTapToRetry = "Not sent · Tap to retry"
    static let sending = "Sending…"
    static let edited = "(edited)"
    static let loadingOlder = "Loading older messages…"
    static let couldNotOpenChat = "Couldn't open this chat."
    static let ok = "OK"
    static let quickReactions = ["👍", "❤️", "😂", "😮", "😢", "🙏"]
```

`ChatScreenModels.swift`:

```swift
struct ChatScreenViewState: BindableState {
    let roomName: String
    /// Groups show sender names above messages; DMs don't.
    let showsSenderNames: Bool
    var items: [TimelineItem] = []
    var isPaginating = false
    var reachedStart = false
    var replyingTo: EventItem?
    var bindings = ChatScreenBindings()
}

struct ChatScreenBindings {
    /// The message whose actions (reactions, reply) are showing.
    var actionsItem: EventItem?
    var errorMessage: String?
}

enum ChatScreenViewAction {
    case appear
    case paginateBackwards
    case send(String)
    case showActions(EventItem)
    case reply(EventItem)
    case cancelReply
    case react(key: String, item: EventItem)
    case retry(EventItem)
    case dismissError
}
```

`ChatScreenViewModelProtocol.swift`:

```swift
protocol ChatScreenViewModelProtocol {
    var context: ChatScreenViewModel.Context { get }
}
```

`ChatScreenViewModel.swift`:

```swift
import Combine
import Foundation

typealias ChatScreenViewModelType = StateStoreViewModelV2<ChatScreenViewState, ChatScreenViewAction>

final class ChatScreenViewModel: ChatScreenViewModelType, ChatScreenViewModelProtocol {
    private let timelineProxy: TimelineProxyProtocol
    private var hasAppeared = false
    private var lastReadItemID: String?

    init(roomName: String, isDirect: Bool, timelineProxy: TimelineProxyProtocol) {
        self.timelineProxy = timelineProxy
        super.init(initialViewState: ChatScreenViewState(roomName: roomName, showsSenderNames: !isDirect))

        timelineProxy.itemsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in self?.update(items) }
            .store(in: &cancellables)
    }

    override func process(viewAction: ChatScreenViewAction) {
        switch viewAction {
        case .appear:
            appear()
        case .paginateBackwards:
            paginateBackwards()
        case .send(let text):
            send(text)
        case .showActions(let item):
            state.bindings.actionsItem = item
        case .reply(let item):
            state.bindings.actionsItem = nil
            state.replyingTo = item
        case .cancelReply:
            state.replyingTo = nil
        case .react(let key, let item):
            state.bindings.actionsItem = nil
            Task { _ = await timelineProxy.toggleReaction(key, to: item.itemID) }
        case .retry(let item):
            retry(item)
        case .dismissError:
            state.bindings.errorMessage = nil
        }
    }

    private func appear() {
        guard !hasAppeared else { return }
        hasAppeared = true
        Task {
            await timelineProxy.subscribe()
            await timelineProxy.markAsRead()
        }
    }

    private func update(_ items: [TimelineItem]) {
        state.items = items.filter(\.isVisible)

        // Keep the read receipt current while the chat is open.
        if let last = state.items.last, last.id != lastReadItemID {
            lastReadItemID = last.id
            Task { await timelineProxy.markAsRead() }
        }
    }

    private func paginateBackwards() {
        guard !state.isPaginating, !state.reachedStart else { return }
        state.isPaginating = true
        Task {
            let result = await timelineProxy.paginateBackwards()
            state.isPaginating = false
            if case .success(let reachedStart) = result {
                state.reachedStart = reachedStart
            }
        }
    }

    private func send(_ text: String) {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        let replyEventID = state.replyingTo?.eventID
        state.replyingTo = nil
        Task {
            if case .failure = await timelineProxy.send(message: message, inReplyTo: replyEventID) {
                state.bindings.errorMessage = WatchStrings.sendFailed
            }
        }
    }

    private func retry(_ item: EventItem) {
        Task {
            if case .failure = await timelineProxy.retrySend(item.itemID) {
                state.bindings.errorMessage = WatchStrings.sendFailed
            }
        }
    }
}
```

`ChatScreenCoordinator.swift`:

```swift
import SwiftUI

final class ChatScreenCoordinator: CoordinatorProtocol {
    private let viewModel: ChatScreenViewModel

    init(roomName: String, isDirect: Bool, timelineProxy: TimelineProxyProtocol) {
        viewModel = ChatScreenViewModel(roomName: roomName, isDirect: isDirect, timelineProxy: timelineProxy)
    }

    func toPresentable() -> AnyView {
        AnyView(ChatScreen(context: viewModel.context))
    }
}
```

- [ ] **Step 5: Implement the chat views**

`View/ChatScreen.swift`:

```swift
import SwiftUI

struct ChatScreen: View {
    @Bindable var context: ChatScreenViewModel.Context

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                if !context.viewState.reachedStart {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(WatchStrings.loadingOlder)
                        .onAppear { context.send(viewAction: .paginateBackwards) }
                }
                ForEach(context.viewState.items) { item in
                    row(for: item)
                }
                composer
            }
        }
        .defaultScrollAnchor(.bottom)
        .navigationTitle(context.viewState.roomName)
        .onAppear { context.send(viewAction: .appear) }
        .sheet(item: $context.actionsItem) { item in
            MessageActionsSheet(item: item,
                                onReact: { context.send(viewAction: .react(key: $0, item: item)) },
                                onReply: { context.send(viewAction: .reply(item)) })
        }
        .alert(context.viewState.bindings.errorMessage ?? "", isPresented: isShowingError) {
            Button(WatchStrings.ok) { context.send(viewAction: .dismissError) }
        }
    }

    @ViewBuilder
    private func row(for item: TimelineItem) -> some View {
        switch item.kind {
        case .event(let event):
            MessageBubble(item: event,
                          showsSenderName: context.viewState.showsSenderNames,
                          onLongPress: { context.send(viewAction: .showActions(event)) },
                          onRetry: { context.send(viewAction: .retry(event)) })
        case .dateDivider(let date):
            Text(date, format: .dateTime.weekday().day().month())
                .font(.caption2)
                .foregroundStyle(Color.compound.textSecondary)
                .frame(maxWidth: .infinity)
        case .readMarker, .timelineStart, .hidden:
            EmptyView()
        }
    }

    private var composer: some View {
        VStack(spacing: 4) {
            if let replyingTo = context.viewState.replyingTo {
                HStack {
                    Text("\(WatchStrings.replyingTo) \(replyingTo.senderName)").font(.caption2).lineLimit(1)
                    Spacer()
                    Button { context.send(viewAction: .cancelReply) } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .accessibilityLabel(WatchStrings.cancel)
                }
            }
            TextFieldLink(prompt: Text(WatchStrings.reply)) {
                Label(WatchStrings.reply, systemImage: "arrowshape.turn.up.left.fill")
            } onSubmit: { text in
                context.send(viewAction: .send(text))
            }
            .tint(Color.compound.bgAccentRest)
        }
        .padding(.top, 4)
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { context.viewState.bindings.errorMessage != nil },
                set: { if !$0 { context.send(viewAction: .dismissError) } })
    }
}

// MARK: - Previews

struct ChatScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { ChatScreen(context: makeViewModel(isDirect: true).context) }
            .previewDisplayName("DM")
        NavigationStack { ChatScreen(context: makeViewModel(isDirect: false).context) }
            .previewDisplayName("Group")
        NavigationStack { ChatScreen(context: replying.context) }
            .previewDisplayName("Replying")
    }

    static var replying: ChatScreenViewModel {
        let viewModel = makeViewModel(isDirect: true)
        viewModel.state.replyingTo = items.compactMap { if case .event(let event) = $0.kind { event } else { nil } }.first
        return viewModel
    }

    static let items: [TimelineItem] = [
        TimelineItem(id: "d", kind: .dateDivider(.now)),
        makeItem("1", "Are we still on for **Saturday**?", own: false, reactions: [.init(key: "👍", count: 2, isHighlighted: true)]),
        makeItem("2", "Yes! See you at 10", own: true),
        makeItem("3", "Waiting for this message", own: false, body: .undecryptable),
        makeItem("4", "Running late", own: true, sendState: .failed)
    ]

    static func makeItem(_ id: String, _ text: String, own: Bool, body: TimelineItemBody? = nil,
                         reactions: [ReactionSummary] = [], sendState: SendState = .sent) -> TimelineItem {
        TimelineItem(id: id, kind: .event(EventItem(itemID: .eventId(eventId: "$\(id)"), eventID: "$\(id)", senderID: own ? "@me:x" : "@bob:x",
                                                    senderName: own ? "Me" : "Bob", isOwn: own, date: .now,
                                                    body: body ?? .text(MessageFormatter.attributedString(from: text)), replyTo: nil,
                                                    reactions: reactions, isEdited: false, sendState: sendState, canBeRepliedTo: true)))
    }

    static func makeViewModel(isDirect: Bool) -> ChatScreenViewModel {
        let proxy = TimelineProxyProtocolMock()
        proxy.itemsPublisher = Just(items).eraseToAnyPublisher()
        let viewModel = ChatScreenViewModel(roomName: isDirect ? "Bob" : "Climbing crew", isDirect: isDirect, timelineProxy: proxy)
        viewModel.state.items = items
        viewModel.state.reachedStart = true
        return viewModel
    }
}
```

Add `import Combine` at the top of `ChatScreen.swift` (the preview uses `Just`). `EventItem` must be `Identifiable` for `.sheet(item:)`. Add this in `TimelineItem.swift`:

```swift
extension EventItem: Identifiable {
    var id: String {
        switch itemID {
        case .eventId(let eventID): eventID
        case .transactionId(let transactionID): transactionID
        }
    }
}
```

`View/MessageBubble.swift`:

```swift
import SwiftUI

struct MessageBubble: View {
    let item: EventItem
    let showsSenderName: Bool
    let onLongPress: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: item.isOwn ? .trailing : .leading, spacing: 2) {
            if showsSenderName, !item.isOwn {
                Text(item.senderName).font(.caption2).foregroundStyle(Color.compound.textSecondary)
            }
            bubble
                .onLongPressGesture(perform: onLongPress)
                .onTapGesture { if item.sendState == .failed { onRetry() } }
            if !item.reactions.isEmpty {
                ReactionsBar(reactions: item.reactions)
            }
            status
        }
        .frame(maxWidth: .infinity, alignment: item.isOwn ? .trailing : .leading)
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let reply = item.replyTo {
                VStack(alignment: .leading) {
                    Text(reply.senderName).font(.caption2.bold())
                    Text(reply.text).font(.caption2).lineLimit(2)
                }
                .padding(4)
                .background(Color.compound.bgSubtleSecondary, in: RoundedRectangle(cornerRadius: 6))
            }
            content
        }
        .padding(8)
        .background(item.isOwn ? Color.compound.bgAccentRest.opacity(0.35) : Color.compound.bgSubtlePrimary,
                    in: RoundedRectangle(cornerRadius: 12))
        .opacity(item.sendState == .sent ? 1 : 0.6)
    }

    @ViewBuilder
    private var content: some View {
        switch item.body {
        case .text(let text), .notice(let text):
            Text(text).font(.body)
        case .emote(let text):
            Text("* \(item.senderName) ").italic() + Text(text).italic()
        case .image(let image):
            ImageThumbnail(image: image)
        case .redacted:
            Text(WatchStrings.messageDeleted).italic().foregroundStyle(Color.compound.textSecondary)
        case .undecryptable:
            Text(WatchStrings.waitingForMessage).italic().foregroundStyle(Color.compound.textSecondary)
        case .unsupported(let description):
            Text(description).foregroundStyle(Color.compound.textSecondary)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch item.sendState {
        case .failed:
            Text(WatchStrings.failedTapToRetry).font(.caption2).foregroundStyle(Color.compound.textCriticalPrimary)
        case .sending:
            Text(WatchStrings.sending).font(.caption2).foregroundStyle(Color.compound.textSecondary)
        case .sent:
            if item.isEdited {
                Text(WatchStrings.edited).font(.caption2).foregroundStyle(Color.compound.textSecondary)
            }
        }
    }
}
```

`View/ReactionsBar.swift`:

```swift
import SwiftUI

struct ReactionsBar: View {
    let reactions: [ReactionSummary]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(reactions) { reaction in
                Text("\(reaction.key) \(reaction.count)")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(reaction.isHighlighted ? Color.compound.bgAccentRest.opacity(0.4) : Color.compound.bgSubtleSecondary,
                                in: Capsule())
            }
        }
    }
}
```

`View/ImageThumbnail.swift`:

```swift
import SwiftUI

struct ImageThumbnail: View {
    let image: ImageBody

    @Environment(\.mediaLoader) private var mediaLoader
    @State private var uiImage: UIImage?
    @State private var isShowingFullScreen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Group {
                if let uiImage {
                    Image(uiImage: uiImage).resizable().scaledToFit()
                } else {
                    Rectangle().fill(Color.compound.bgSubtleSecondary)
                        .aspectRatio(image.aspectRatio ?? 1, contentMode: .fit)
                        .overlay { ProgressView() }
                }
            }
            .frame(maxWidth: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture { if uiImage != nil { isShowingFullScreen = true } }
            if let caption = image.caption {
                Text(caption).font(.footnote)
            }
        }
        .task(id: image.source) {
            if let data = await mediaLoader.loadThumbnail(image.thumbnailSource ?? image.source, 300, 300) {
                uiImage = UIImage(data: data)
            }
        }
        .fullScreenCover(isPresented: $isShowingFullScreen) {
            if let uiImage {
                Image(uiImage: uiImage).resizable().scaledToFit().ignoresSafeArea()
            }
        }
        .accessibilityLabel(image.caption ?? WatchStrings.photo)
    }
}
```

`View/MessageActionsSheet.swift`:

```swift
import SwiftUI

struct MessageActionsSheet: View {
    let item: EventItem
    let onReact: (String) -> Void
    let onReply: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(WatchStrings.quickReactions, id: \.self) { key in
                        Button(key) { onReact(key) }
                            .font(.title3)
                            .buttonStyle(.plain)
                    }
                }
                if item.canBeRepliedTo, item.eventID != nil {
                    Button(WatchStrings.reply, systemImage: "arrowshape.turn.up.left", action: onReply)
                }
            }
        }
    }
}
```

- [ ] **Step 6: Wire the chat screen into the session flow**

In `UserSessionFlowCoordinator.destination(for:)`, replace the placeholder `.chat` case with an asynchronously loaded coordinator:

```swift
        case .chat(let roomID, let name, let isDirect):
            coordinator = ChatLoaderCoordinator(roomID: roomID, name: name, isDirect: isDirect, clientProxy: clientProxy)
```

and replace `PlaceholderCoordinator` with:

```swift
/// Opens the room's timeline, then shows the chat screen (or an error if the room can't be opened).
private final class ChatLoaderCoordinator: CoordinatorProtocol {
    @Observable final class Model {
        var chat: ChatScreenCoordinator?
        var failed = false
    }

    private let roomID: String
    private let name: String
    private let isDirect: Bool
    private let clientProxy: ClientProxyProtocol
    private let model = Model()

    init(roomID: String, name: String, isDirect: Bool, clientProxy: ClientProxyProtocol) {
        self.roomID = roomID
        self.name = name
        self.isDirect = isDirect
        self.clientProxy = clientProxy
    }

    func start() {
        Task { [model, roomID, name, isDirect, clientProxy] in
            if let timelineProxy = await clientProxy.timelineProxy(for: roomID) {
                model.chat = ChatScreenCoordinator(roomName: name, isDirect: isDirect, timelineProxy: timelineProxy)
            } else {
                model.failed = true
            }
        }
    }

    func toPresentable() -> AnyView {
        AnyView(ChatLoaderView(model: model, name: name))
    }
}

private struct ChatLoaderView: View {
    let model: ChatLoaderCoordinator.Model
    let name: String

    var body: some View {
        if let chat = model.chat {
            chat.toPresentable()
        } else if model.failed {
            Text(WatchStrings.couldNotOpenChat).navigationTitle(name)
        } else {
            ProgressView().navigationTitle(name)
        }
    }
}
```

Prune cached child coordinators when routes are popped. In `start()`, add:

```swift
        withObservationTracking { _ = navigation.path } onChange: { [weak self] in
            Task { @MainActor in self?.pruneChildCoordinators() }
        }
```

and the method:

```swift
    private func pruneChildCoordinators() {
        let liveRoutes = Set(navigation.path)
        childCoordinators = childCoordinators.filter { liveRoutes.contains($0.key) }
        // Observation tracking fires once; re-arm it.
        withObservationTracking { _ = navigation.path } onChange: { [weak self] in
            Task { @MainActor in self?.pruneChildCoordinators() }
        }
    }
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `xcodegen`, then the standard test command (full run).
Expected: all suites pass, including ChatScreenViewModelTests (7).

- [ ] **Step 8: Record provenance and commit**

Append to `SHARED_FROM_IOS.md`:

```markdown
| `ElementXWatch/Sources/Services/Timeline/TimelineProxy.swift` | `ElementX/Sources/Services/Timeline/TimelineProxy.swift` | Live timeline only: subscribe, back-paginate, send / reply (Markdown), reactions, retry, read receipts. |
```

```bash
git add ElementXWatch UnitTests SHARED_FROM_IOS.md
git commit -m "Add the chat screen with replies, reactions and retry

Opens a room's live timeline, loads older messages on scroll, sends
dictated or typed replies (optionally to a specific message), toggles
quick reactions, retries failed sends and keeps read receipts current.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

### Task 18: App coordinator, session restore and lifecycle

**Files:**
- Create: `ElementXWatch/Sources/Services/Session/UserSessionRestorer.swift`
- Create: `ElementXWatch/Sources/Application/AppCoordinator.swift`
- Modify: `ElementXWatch/Sources/Application/ElementXWatchApp.swift`
- Test: `UnitTests/Sources/AppCoordinatorTests.swift`

**Interfaces:**
- Consumes: `SessionStoreProtocol` (Task 9), `ClientFactoryProtocol` (Task 10), `ClientProxy`, `ClientProxyProtocol` (Task 12), `QRLoginServiceProtocol` (Task 13), `AuthenticationFlowCoordinator` (Task 14), `UserSessionFlowCoordinator` (Task 15).
- Produces:
  ```swift
  enum UserSessionRestorerError: Error { case noSession, restoreFailed }
  // sourcery: AutoMockable
  protocol UserSessionRestorerProtocol { func restore() async -> Result<ClientProxyProtocol, UserSessionRestorerError> }
  final class UserSessionRestorer: UserSessionRestorerProtocol { init(sessionStore: SessionStoreProtocol, clientFactory: ClientFactoryProtocol) }
  @Observable final class AppCoordinator {
      enum Phase: Equatable { case launching, signedOut, signedIn }
      private(set) var phase: Phase
      init(sessionStore: SessionStoreProtocol, restorer: UserSessionRestorerProtocol, qrLoginService: QRLoginServiceProtocol)
      func start() async
      func handleScenePhase(_ scenePhase: ScenePhase)
      func toPresentable() -> AnyView }
  ```

- [ ] **Step 1: Write the failing tests**

`UnitTests/Sources/AppCoordinatorTests.swift`:

```swift
@testable import ElementXWatch
import SwiftUI
import Testing

@Suite
struct AppCoordinatorTests {
    @Test
    func withoutASessionTheUserSignsIn() async {
        let (coordinator, restorer, _, _) = makeCoordinator()
        restorer.restoreReturnValue = .failure(.noSession)

        await coordinator.start()

        #expect(coordinator.phase == .signedOut)
    }

    @Test
    func aRestoredSessionStartsSyncingWhenActive() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)

        await coordinator.start()
        coordinator.handleScenePhase(.active)

        #expect(coordinator.phase == .signedIn)
        try await waitUntil { setup.clientProxy.startSyncCallsCount == 1 }
    }

    @Test
    func goingToTheBackgroundStopsSync() async throws {
        let (coordinator, restorer, _, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()

        coordinator.handleScenePhase(.background)

        try await waitUntil { setup.clientProxy.stopSyncCallsCount == 1 }
    }

    @Test
    func aFailedRestoreFallsBackToSignIn() async {
        let (coordinator, restorer, _, _) = makeCoordinator()
        restorer.restoreReturnValue = .failure(.restoreFailed)

        await coordinator.start()

        #expect(coordinator.phase == .signedOut)
    }

    @Test
    func authErrorsClearTheSession() async throws {
        let (coordinator, restorer, sessionStore, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()

        setup.actions.send(.authError(isSoftLogout: false))

        try await waitUntil { coordinator.phase == .signedOut }
        #expect(sessionStore.clearCallsCount == 1)
    }

    @Test
    func signingOutLogsOutAndClears() async throws {
        let (coordinator, restorer, sessionStore, setup) = makeCoordinator()
        restorer.restoreReturnValue = .success(setup.clientProxy)
        await coordinator.start()

        await coordinator.signOut()

        #expect(setup.clientProxy.logoutCallsCount == 1)
        #expect(sessionStore.clearCallsCount == 1)
        #expect(coordinator.phase == .signedOut)
    }

    // MARK: - Helpers

    private func makeCoordinator() -> (AppCoordinator, UserSessionRestorerProtocolMock, SessionStoreProtocolMock, Setup) {
        let restorer = UserSessionRestorerProtocolMock()
        let sessionStore = SessionStoreProtocolMock()
        let coordinator = AppCoordinator(sessionStore: sessionStore, restorer: restorer, qrLoginService: QRLoginServiceProtocolMock())
        return (coordinator, restorer, sessionStore, Setup())
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the standard test command with `-only-testing:UnitTests/AppCoordinatorTests`.
Expected: build failure `cannot find 'AppCoordinator' in scope`.

- [ ] **Step 3: Implement the restorer**

`Services/Session/UserSessionRestorer.swift`:

```swift
enum UserSessionRestorerError: Error {
    case noSession
    case restoreFailed
}

// sourcery: AutoMockable
protocol UserSessionRestorerProtocol {
    func restore() async -> Result<ClientProxyProtocol, UserSessionRestorerError>
}

final class UserSessionRestorer: UserSessionRestorerProtocol {
    private let sessionStore: SessionStoreProtocol
    private let clientFactory: ClientFactoryProtocol

    init(sessionStore: SessionStoreProtocol, clientFactory: ClientFactoryProtocol) {
        self.sessionStore = sessionStore
        self.clientFactory = clientFactory
    }

    func restore() async -> Result<ClientProxyProtocol, UserSessionRestorerError> {
        guard let token = sessionStore.restorationToken() else { return .failure(.noSession) }

        do {
            let client = try await clientFactory.makeRestoredClient(token: token)
            MXLog.info("Restored the session for \(token.session.userId)")
            return try await .success(ClientProxy.make(client: client))
        } catch {
            // Restoring is local (no discovery); a failure means the stored data is unusable.
            MXLog.error("Failed restoring the session: \(error)")
            sessionStore.clear()
            return .failure(.restoreFailed)
        }
    }
}
```

- [ ] **Step 4: Implement the app coordinator and entry point**

`Application/AppCoordinator.swift`:

```swift
import Combine
import Observation
import SwiftUI

/// Decides between the sign-in flow and the signed-in session, and drives sync from the app lifecycle.
@Observable final class AppCoordinator {
    enum Phase: Equatable {
        case launching
        case signedOut
        case signedIn
    }

    private(set) var phase: Phase = .launching

    @ObservationIgnored private let sessionStore: SessionStoreProtocol
    @ObservationIgnored private let restorer: UserSessionRestorerProtocol
    @ObservationIgnored private let qrLoginService: QRLoginServiceProtocol
    @ObservationIgnored private var clientProxy: ClientProxyProtocol?
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var isActive = false
    private var authenticationFlow: AuthenticationFlowCoordinator?
    private var userSessionFlow: UserSessionFlowCoordinator?

    init(sessionStore: SessionStoreProtocol, restorer: UserSessionRestorerProtocol, qrLoginService: QRLoginServiceProtocol) {
        self.sessionStore = sessionStore
        self.restorer = restorer
        self.qrLoginService = qrLoginService
    }

    func start() async {
        switch await restorer.restore() {
        case .success(let clientProxy):
            showSession(clientProxy)
        case .failure:
            showAuthentication()
        }
    }

    func handleScenePhase(_ scenePhase: ScenePhase) {
        isActive = scenePhase == .active
        guard let clientProxy else { return }
        Task {
            if scenePhase == .active {
                await clientProxy.startSync()
            } else if scenePhase == .background {
                await clientProxy.stopSync()
            }
        }
    }

    func signOut() async {
        MXLog.info("Signing out")
        await clientProxy?.logout()
        clearSession()
    }

    func toPresentable() -> AnyView {
        AnyView(AppCoordinatorView(coordinator: self))
    }

    fileprivate var currentView: AnyView {
        switch phase {
        case .launching: AnyView(ProgressView())
        case .signedOut: authenticationFlow?.toPresentable() ?? AnyView(ProgressView())
        case .signedIn: userSessionFlow?.toPresentable() ?? AnyView(ProgressView())
        }
    }

    private func showAuthentication() {
        cancellables.removeAll()
        clientProxy = nil
        userSessionFlow = nil

        let flow = AuthenticationFlowCoordinator(qrLoginService: qrLoginService)
        flow.signedInPublisher
            .sink { [weak self] clientProxy in self?.showSession(clientProxy) }
            .store(in: &cancellables)
        flow.start()
        authenticationFlow = flow
        phase = .signedOut
    }

    private func showSession(_ clientProxy: ClientProxyProtocol) {
        cancellables.removeAll()
        authenticationFlow = nil
        self.clientProxy = clientProxy

        clientProxy.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .authError:
                    // Soft logout would need a re-login flow; the watch simply signs in again.
                    self?.clearSession()
                }
            }
            .store(in: &cancellables)

        let flow = UserSessionFlowCoordinator(clientProxy: clientProxy)
        flow.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .signOut: Task { await self?.signOut() }
                }
            }
            .store(in: &cancellables)
        flow.start()
        userSessionFlow = flow
        phase = .signedIn

        if isActive {
            Task { await clientProxy.startSync() }
        }
    }

    private func clearSession() {
        sessionStore.clear()
        showAuthentication()
    }
}

private struct AppCoordinatorView: View {
    let coordinator: AppCoordinator

    var body: some View {
        coordinator.currentView
    }
}
```

`Application/ElementXWatchApp.swift` (replace the Task 6 shell):

```swift
import SwiftUI

@main
struct ElementXWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appCoordinator: AppCoordinator

    init() {
        Tracing.setUp()

        let keychainStore = KeychainStore(service: WatchAppSettings.keychainService)
        let sessionStore = SessionStore(keychainStore: keychainStore)
        let clientFactory = ClientFactory(transport: URLSessionTransport(), sessionDelegate: SessionDelegate(keychainStore: keychainStore))
        _appCoordinator = State(initialValue: AppCoordinator(sessionStore: sessionStore,
                                                             restorer: UserSessionRestorer(sessionStore: sessionStore, clientFactory: clientFactory),
                                                             qrLoginService: QRLoginService(clientFactory: clientFactory, sessionStore: sessionStore)))
    }

    var body: some Scene {
        WindowGroup {
            appCoordinator.toPresentable()
                .task { await appCoordinator.start() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            appCoordinator.handleScenePhase(newPhase)
        }
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `xcodegen`, then the standard test command (full run).
Expected: all suites pass, including AppCoordinatorTests (6).

- [ ] **Step 6: Smoke-run in the simulator**

```bash
xcodebuild -project ElementXWatch.xcodeproj -scheme ElementXWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' -derivedDataPath build build 2>&1 | tail -2
SIM=$(xcrun simctl list devices available | grep "Apple Watch Series 11 (46mm)" | head -1 | grep -oE '[0-9A-F-]{36}')
xcrun simctl boot "$SIM" 2>/dev/null; xcrun simctl install "$SIM" build/Build/Products/Debug-watchsimulator/ElementXWatch.app
xcrun simctl launch "$SIM" io.ilie.elementx.watch
sleep 5; xcrun simctl io "$SIM" screenshot /tmp/elementx-watch-launch.png
```

Expected: `** BUILD SUCCEEDED **`, the app launches, and the screenshot shows "Sign in with your iPhone" with a "Show code" button. Tap "Show code" in the simulator: a QR code appears within a few seconds. That proves discovery and the rendezvous request against matrix.org went through `URLSession`.

- [ ] **Step 7: Commit**

```bash
git add ElementXWatch UnitTests
git commit -m "Add the app coordinator with session restore and sync lifecycle

Restores a stored session on launch or shows QR sign-in, starts sync
while the app is active and stops it in the background, and returns to
sign-in after sign-out or when the server rejects the session.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

---

### Task 19: Device build, measurements and the testing session checklist

**Files:**
- Create: `TESTING.md`

**Interfaces:**
- Consumes: everything above. Produces the sign-off record for the spec's §7 manual checklist and definition of done.

- [ ] **Step 1: Build the full SDK (all slices) and the app for a device**

```bash
cd ~/Developer/git/github.com/element-hq/element-x-watchos
Tools/build-sdk.sh
ls Packages/MatrixRustSDK/MatrixSDKFFI.xcframework
xcodegen
cp -n Config/Local.xcconfig.example Config/Local.xcconfig   # then set DEVELOPMENT_TEAM to your Personal Team ID
xcodebuild -project ElementXWatch.xcodeproj -scheme ElementXWatch -destination 'generic/platform=watchOS' -configuration Release -derivedDataPath build build 2>&1 | tail -2
```

Expected: the xcframework lists `watchos-arm64_arm64_32` (or separate `watchos-arm64` and `watchos-arm64_32` directories) plus `watchos-arm64-simulator`, and the device build prints `** BUILD SUCCEEDED **`. Your Personal Team ID is in Xcode → Settings → Accounts → (your Apple ID) → Team ID.

- [ ] **Step 2: Measure binary size**

```bash
du -sh build/Build/Products/Release-watchos/ElementXWatch.app
xcrun size -arch arm64 build/Build/Products/Release-watchos/ElementXWatch.app/ElementXWatch | tail -1
xcrun size -arch arm64_32 build/Build/Products/Release-watchos/ElementXWatch.app/ElementXWatch | tail -1
```

Record both numbers in `TESTING.md`. If the app is larger than 75 MB, note it as a risk for the upstream conversation (sideloading still works).

- [ ] **Step 3: Install on the Apple Watch Series 9 and run the checklist**

Connect the paired iPhone by cable, open `ElementXWatch.xcodeproj`, select the watch as the run destination and the `ElementXWatch` scheme, then Run. On the phone, in Element X: tap the version number in Settings 7 times, then turn on **Developer options → Link new device**.

Create `TESTING.md` and fill it in while testing:

```markdown
# Sub-project 1 testing session

Date: YYYY-MM-DD · Watch: Apple Watch Series 9 (arm64), watchOS __ · SDK fork: `<git rev-parse --short HEAD>` · App: `<git rev-parse --short HEAD>`

## Measurements

| Item | Value |
|---|---|
| Release .app size | |
| arm64 __TEXT | |
| arm64_32 __TEXT (built, not run) | |
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

## Transport audit

- [ ] Console (Xcode → Devices → Open Console, filter `io.ilie.elementx.watch`) shows no `127.0.0.1:9` / proxy connection errors during the session.
- [ ] Rust logs downloaded from the app container (`Library/Caches/Logs/rust*.log`) show no reqwest connection attempts.

## Issues found

-
```

To read memory, use Xcode's Debug navigator → Memory while running from Xcode. To pull Rust logs, use Xcode → Window → Devices and Simulators → the watch → Installed Apps → ElementXWatch → ⚙︎ → Download Container.

- [ ] **Step 4: Commit**

```bash
git add TESTING.md
git commit -m "Record the sub-project 1 testing session on Apple Watch Series 9

Captures binary size, memory, the spec's manual checklist results and
the transport audit for QR login and chats on a real watch.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX"
```

Sub-project 1 is done when every checklist row passes (or has an agreed follow-up), all automated tests pass, and a fresh clone builds with `Tools/build-sdk.sh` → `xcodegen` → Xcode build.
