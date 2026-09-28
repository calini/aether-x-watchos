import CompoundDesignTokens
@testable import AetherXWatch
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
