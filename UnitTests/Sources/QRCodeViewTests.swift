//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

@testable import AetherXWatch
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
