//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

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
