# Element X watchOS — Design (Sub-project 1.1: server choice, password sign-in, emoji verification)

Date: 2026-09-26
Status: Approved design, pending written-spec review
Builds on: `2026-09-25-watchos-client-design.md` (sub-project 1)

## 1. Why

Testing sub-project 1 in the simulator against matrix.org failed at the first step: matrix.org answers `POST /_matrix/client/unstable/org.matrix.msc4108/rendezvous` with **404**, so QR sign-in can't work there, and the app offered no alternative. The user wants:

- **Server choice first.** A server screen prefilled with `matrix.org`, editable with the normal watchOS text input (so the iPhone can remote-type), shown before any sign-in method.
- **A choice of sign-in method.** Username and password, and/or QR code, offered according to what the chosen server supports.
- **Verification of a password sign-in** from another device by comparing emojis. Per the user's choice (**option B**), this step is **skippable**: chats open straight away, and verification stays available from Settings.

## 2. Findings that shape the design

- Password login exists in the SDK: `Client.login(username:password:initialDeviceName:deviceId:)`. matrix.org reports `supportsPasswordLogin == true` (confirmed in the sub-project 1 spike).
- The SDK can tell whether QR sign-in will work: `Client.isLoginWithQrCodeSupported()`, which is true only for OAuth servers that advertise MSC4108. So the QR option is shown only when it works, and no 404 guessing is needed.
- Emoji (SAS) verification is exposed by `SessionVerificationController`:
  - `requestDeviceVerification`, `startSasVerification`, `approveVerification`, `declineVerification`, `cancelVerification`;
  - delegate callbacks for accepted, started-SAS, verification data, finished, cancelled and failed;
  - the data is `SessionVerificationData.emojis(…)` (**7 emojis**) or `.decimals(…)`.

  A successful SAS verification makes the other device share the cross-signing secrets and the backup key, so older messages decrypt.
- **QR-code verification is not exposed by the FFI.** The Rust crypto crate supports it, but it would need new FFI surface in the SDK fork, and the watch can only *display* a code, not scan one. It's **out of scope** here and is a follow-up (§8).

## 3. Scope

In scope:
1. The server selection screen (default `matrix.org`, editable, validated).
2. The sign-in method screen (Password and/or QR code, by server capability).
3. The password sign-in screen.
4. The QR sign-in flow, now using the chosen server instead of the hard-coded `matrix.org`.
5. A skippable "Verify this watch" flow with emoji comparison, reachable:
   - right after a password sign-in;
   - from Settings while the session is unverified.
6. Better QR errors: an unexpected rendezvous 404 is reported as "not supported" rather than "Something went wrong".
7. `TESTING.md` correction: find the Team ID in the Apple Development certificate (the `OU` field) rather than in Xcode → Settings → Accounts, which doesn't show it for Personal Teams.

Out of scope:
- QR-code verification;
- recovery-key entry;
- answering verification requests started by *other* devices;
- SSO or web OAuth sign-in;
- account registration.

## 4. Flow

```
Launch (no session)
  → Server screen: "matrix.org" [edit] → Continue
      (build a login client for the server: discovery + login details)
  → Method screen: [Sign in with password] (if supportsPasswordLogin)
                   [Sign in with iPhone (QR)] (if isLoginWithQrCodeSupported)
      ├─ Password screen → Sign in → session saved
      │     → Verify screen (skippable) → Chats
      └─ QR flow (existing, on the chosen server) → session saved (already verified) → Chats
```

- The **Server screen** has one `TextField` (with `.textContentType(.URL)`, autocapitalisation off) and a Continue button. On Continue the watch builds a login client for the input: a server name or a full URL, as `serverNameOrHomeserverUrl` accepts. It shows a progress state, then either the method screen or an inline error ("Couldn't reach this server" / "This server isn't supported" when there's no sliding sync) with the field still editable.
- The **Method screen** shows the server name and one button per supported method. If the server supports neither, it shows "This server doesn't support signing in from a watch" and a Back button.
- The **Password screen** has a username `TextField` (accepting `alice` or `@alice:server`, autocapitalisation off) and a `SecureField` for the password, then Sign in.
  - Errors are shown inline: wrong username or password (`M_FORBIDDEN`), too many attempts (`M_LIMIT_EXCEEDED`), or network.
  - The initial device name is `Element X Watch`.
  - The password is never logged or kept after the call.
- The **Verify screen** (after a password sign-in, or from Settings) has three stages:
  - **Intro:** "Verify this watch", explaining "Open Element X on your iPhone to accept". Buttons: **Start** and **Not now**.
  - **Waiting:** "Accept the request on your iPhone…". Button: **Cancel**.
  - **Emojis:** the 7 emojis in a scrollable list, each with its description. Buttons: **They match** and **They don't match**.
  - The outcomes are **Verified** (then Done), **Cancelled** or **Failed** (both with Try again / Not now), and **Declined / didn't match** (explanatory text, then Done).
- **Settings** shows a "Verify this watch" row while `SessionVerification` is `.unverified`, and it opens the same Verify screen.

## 5. Components (watch app)

| Unit | Responsibility | Notes |
|---|---|---|
| `AuthenticationService` (replaces the server part of `QRLoginService`) | `configure(server:) async -> Result<LoginOptions, AuthenticationError>` builds a login client (fresh `SessionDirectories` + passphrase) and reports `LoginOptions { serverName, supportsPassword, supportsQRCode }`. `login(username:password:) async -> Result<ClientProxyProtocol, AuthenticationError>` saves the session and returns a `ClientProxy`. `reset()` deletes the configured client's directories when the user goes back or picks another server. | Derived from iOS `AuthenticationService` (`configure`/`login`/`makeClient`). Keeps the "clear only what this attempt saved" rule from sub-project 1. |
| `QRLoginService` | The existing generate flow, now running on the client that `AuthenticationService` configured, not on `WatchAppSettings.defaultServerName`. | Maps a rendezvous `NotFound` or a 404 to `.serverNotSupported`. |
| `SessionVerificationControllerProxy` (+ protocol, AutoMockable) | Wraps `SessionVerificationController` (request, start SAS, approve, decline, cancel) and publishes `SessionVerificationControllerProxyAction` (accepted, startedSAS, receivedEmojis([Emoji]), finished, cancelled, failed) on the main actor. | Derived from iOS `SessionVerificationControllerProxy`. `Emoji` = `symbol` + `description`. |
| `ClientProxy.sessionVerificationController() async -> SessionVerificationControllerProxyProtocol?` | Creates the controller for the signed-in client. | New protocol method. |
| Screens: `ServerSelectionScreen`, `LoginMethodScreen`, `PasswordLoginScreen`, `SessionVerificationScreen` | MVVM-C, like the existing screens, with a `PreviewProvider` for every state. | `QRLoginScreen` stays as it is, reached from the method screen. |
| `AuthenticationFlowCoordinator` | Owns a `NavigationStack`: server → method → password \| QR. Emits `signedIn(ClientProxyProtocol, needsVerification: Bool)`: true for password, false for QR. | |
| `UserSessionFlowCoordinator` / `AppCoordinator` | When `needsVerification` is true, present the Verify screen as a sheet over Chats (dismissable, matching option B). Settings gets a "Verify this watch" action that opens it. | `SettingsScreen` gains an `.verifySession` action while unverified. |

`WatchAppSettings.defaultServerName` stays `"matrix.org"` and is only used to prefill the server screen.

## 6. Errors

| Where | Condition | Shown |
|---|---|---|
| Server | Discovery or network failure | "Couldn't reach this server." |
| Server | No sliding sync (`SlidingSyncNotAvailable` / builder error) | "This server isn't supported." |
| Method | Neither password nor QR is available | "This server doesn't support signing in from a watch." |
| Password | `M_FORBIDDEN` | "Wrong username or password." |
| Password | `M_LIMIT_EXCEEDED` | "Too many attempts. Try again later." |
| Password | Other or network | "Couldn't sign in. Try again." |
| QR | Rendezvous 404 / `NotFound` | "This server doesn't support signing in with a QR code." |
| Verify | `didFail` / controller unavailable | "Verification failed.", with Try again / Not now |
| Verify | `didCancel` | "Verification was cancelled.", with Try again / Not now |

Logging follows the global rules: never log passwords, tokens or emoji values. Server names and Matrix IDs are fine.

## 7. Testing

- **Unit tests (Swift Testing, Sourcery mocks):**
  - Server view model: default text, empty input disabled, success leads to the method screen with the right options, errors map to the right copy, editing after an error.
  - Method view model: the buttons shown for each `LoginOptions` combination.
  - Password view model: disabled until both fields are non-empty; error mapping; success emits `signedIn(…, needsVerification: true)`.
  - Verification view model: the full state machine driven by proxy actions, including cancel, fail, decline, "They match" calling approve, and "Not now" dismissing.
  - `AuthenticationFlowCoordinator` routing.
  - The `AppCoordinator`/`UserSessionFlowCoordinator` sheet: shown only after a password sign-in, dismissable, and reachable from Settings while unverified.
  - `QRLoginError` mapping for 404 / `NotFound`.
- **Manual (added to `TESTING.md`):**
  - matrix.org, then Password, then sign in, then Verify: Element X on the iPhone accepts, the emojis match on both devices, the watch shows Verified, and older encrypted DM history decrypts.
  - Skip verification: chats open, Settings shows "Verify this watch", and verifying later works.
  - A server that supports QR (if one is available) still offers and completes QR sign-in.

## 8. Follow-ups (not in this sub-project)

- QR-code verification: FFI surface in the SDK fork (generate a QR for the verification request, then confirm the reciprocation), with the watch displaying the code.
- Answering verification requests started from other devices.
- Recovery-key entry (possible with iPhone remote typing).
