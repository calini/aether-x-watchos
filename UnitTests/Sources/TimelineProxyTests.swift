//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

@testable import AetherXWatch
import Foundation
import MatrixRustSDK
import Testing

@Suite
struct TimelineProxyTests {
    @Test
    func retryingReEnablesTheSendQueueBeforeResending() async {
        let recorder = CallRecorder()
        let sendHandle = SendHandleSpy { await recorder.record("resend") }

        let result = await TimelineProxy.resend(sendHandle) { recorder.record("enableSendQueue") }

        #expect((try? result.get()) != nil)
        #expect(recorder.calls == ["enableSendQueue", "resend"])
    }

    @Test
    func aFailedResendIsReported() async {
        let sendHandle = SendHandleSpy { throw ClientError.Generic(msg: "offline", details: nil) }

        let result = await TimelineProxy.resend(sendHandle) { }

        #expect(throws: TimelineProxyError.self) { try result.get() }
    }

    @Test
    func voiceMessagesAreSentWithAFixedName() {
        let bytes = Data([0x4F, 0x67, 0x67, 0x53])

        let parameters = TimelineProxy.voiceMessageUploadParameters(bytes: bytes)

        #expect(parameters.source == .data(bytes: bytes, filename: "voice-message.ogg"))
    }
}

// MARK: - Helpers

private final class CallRecorder {
    private(set) var calls: [String] = []

    func record(_ call: String) {
        calls.append(call)
    }
}

/// A fake send handle with no Rust object behind it.
private nonisolated final class SendHandleSpy: SendHandleProtocol {
    private let onResend: @Sendable () async throws -> Void

    init(onResend: @escaping @Sendable () async throws -> Void) {
        self.onResend = onResend
    }

    func abort(reason: String?) async throws -> Bool {
        false
    }

    func tryResend() async throws {
        try await onResend()
    }
}
