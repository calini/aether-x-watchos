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
    static let photoAccessibilityLabel = "Photo"
    static let video = "🎥 Video"
    static let audio = "🎵 Audio"
    static let file = "📎 File"
    static let location = "Location"
    static let liveLocation = "Live location"
    static let liveLocationEnded = "Live location ended"
    static let live = "Live"
    static let openInMaps = "Open in Maps"
    static let locationPlaceholderIcon = "📍"
    static let gallery = "🖼️ Gallery"
    static let sticker = "Sticker"
    static let unsupportedMessage = "Unsupported message"

    static let qrErrorExpired = "The code expired. Try again."
    static let qrErrorDeclined = "Sign-in was declined on your phone."
    static let qrErrorCancelled = "Sign-in was cancelled."
    static let qrErrorInsecure = "The codes didn't match. Try again."
    static let qrErrorLinkingNotSupported = "Your phone can't link devices. Update Element X and turn on Link new device."
    static let qrErrorServerNotSupported = "This server doesn't support signing in with a QR code."
    static let qrErrorOtherDeviceNotSignedIn = "Element X on your phone isn't signed in."
    static let qrErrorUnknown = "Something went wrong. Try again."

    static let serverUnreachable = "Couldn't reach this server."
    static let serverNotSupported = "This server isn't supported."
    static let wrongCredentials = "Wrong username or password."
    static let rateLimited = "Too many attempts. Try again later."
    static let signInFailed = "Couldn't sign in. Try again."

    static let serverTitle = "Server"
    static let serverPrompt = "Your server"
    static let continueAction = "Continue"
    static let signInMethodTitle = "Sign in"
    static let signInWithPassword = "Sign in with password"
    static let signInWithQRCode = "Sign in with QR code"
    static let noSignInMethods = "This server doesn't support signing in from a watch."
    static let usernamePrompt = "Username"
    static let passwordPrompt = "Password"
    static let signInAction = "Sign in"

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

    static let verifyTitle = "Verify this watch"
    static let verifyIntro = "Open Element X on your iPhone to accept, then compare the emojis."
    static let verifyStart = "Start"
    static let notNow = "Not now"
    static let verifyWaiting = "Accept the request on your iPhone…"
    static let verifyCompare = "Do these match your iPhone?"
    static let theyMatch = "They match"
    static let theyDontMatch = "They don't match"
    static let verificationSucceeded = "This watch is verified."
    static let verificationDeclined = "The emojis didn't match, so this watch wasn't verified."
    static let verificationCancelled = "Verification was cancelled."
    static let verificationFailed = "Verification failed."
    static let done = "Done"

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

    static let reply = "Reply"
    static let replyingTo = "Replying to"
    static let moreReactions = "More reactions"
    static let sendFailed = "Couldn't send your message."
    static let resendFailed = "Couldn't resend. Try again later."
    static let failedTapToRetry = "Not sent · Tap to retry"
    static let sending = "Sending…"
    static let edited = "(edited)"
    static let loadingOlder = "Loading older messages…"
    static let loadOlderMessages = "Load older messages"
    static let couldNotOpenChat = "Couldn't open this chat."
    static let ok = "OK"
    static let quickReactions = ["👍", "❤️", "😂", "😮", "😢", "🙏"]

    static let attachments = "Attachments"
    static let attachmentsTitle = "Attach"
    static let locationTitle = "Location"
    static let locationRow = "📍 Location"
    static let sendCurrentLocation = "Send current location"
    static let shareLive15 = "Share live · 15 min"
    static let shareLive60 = "Share live · 1 hour"
    static let findingLocation = "Finding your location…"
    static let locationFailed = "Couldn't get your location."
    static let locationAccessOff = "Location access is off. Turn it on in Settings → Privacy & Security → Location Services."
    static let sendLocationFailed = "Couldn't send location."
    static let startLiveFailed = "Couldn't start live location."
    static let shareHere = "Share here"
    static let anotherChat = "another chat"

    static func replaceLiveShareTitle(roomName: String) -> String {
        "Stop sharing in \(roomName) and share here instead?"
    }

    /// "Live · updated 30 s ago", rounded down to seconds, minutes or hours.
    static func liveUpdated(secondsAgo: Int) -> String {
        let seconds = max(secondsAgo, 0)
        let elapsed = switch seconds {
        case ..<60: "\(seconds) s"
        case ..<3600: "\(seconds / 60) min"
        default: "\(seconds / 3600) h"
        }
        return "Live · updated \(elapsed) ago"
    }
}
