//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

/// English UI strings for the watch app (no localisation yet).
/// Nonisolated so callers off the main actor (e.g. `QRLoginError`, an `Error` type) can read them too.
nonisolated enum WatchStrings {
    static let appName = "Element X"
    static let tryAgain = "Try again"
    static let cancel = "Cancel"
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

    static let qrErrorExpired = "The code expired. Try again."
    static let qrErrorDeclined = "Sign-in was declined on your phone."
    static let qrErrorCancelled = "Sign-in was cancelled."
    static let qrErrorInsecure = "The codes didn't match. Try again."
    static let qrErrorLinkingNotSupported = "Your phone can't link devices. Update Element X and turn on Link new device."
    static let qrErrorServerNotSupported = "Your server doesn't support signing in this way."
    static let qrErrorOtherDeviceNotSignedIn = "Element X on your phone isn't signed in."
    static let qrErrorUnknown = "Something went wrong. Try again."

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
}
