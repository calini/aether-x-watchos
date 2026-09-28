//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

@testable import AetherXWatch
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
