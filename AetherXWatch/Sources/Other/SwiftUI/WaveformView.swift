//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

/// A voice message's waveform as bars, filled up to `progress`.
struct WaveformView: View {
    private static let barWidth: CGFloat = 2
    private static let barSpacing: CGFloat = 2
    private static let minimumBarHeight: CGFloat = 2

    /// Levels in 0…1, resampled to fit the width.
    let waveform: [Float]
    /// In 0…1.
    var progress: Double = 0

    var body: some View {
        Canvas { context, size in
            let bars = Self.bars(from: waveform, count: Int((size.width + Self.barSpacing) / (Self.barWidth + Self.barSpacing)))
            for (index, level) in bars.enumerated() {
                let x = CGFloat(index) * (Self.barWidth + Self.barSpacing)
                let height = max(CGFloat(level) * size.height, Self.minimumBarHeight)
                let bar = Path(roundedRect: CGRect(x: x, y: (size.height - height) / 2, width: Self.barWidth, height: height),
                               cornerRadius: Self.barWidth / 2)
                let isPlayed = (x + Self.barWidth / 2) / size.width <= progress
                context.fill(bar, with: .color(isPlayed ? Color.compound.iconPrimary : Color.compound.iconQuaternary))
            }
        }
        .accessibilityHidden(true)
    }

    /// The loudest level in each of `count` buckets, so short peaks survive the resampling.
    static func bars(from waveform: [Float], count: Int) -> [Float] {
        guard count > 0, !waveform.isEmpty else { return [] }
        return (0..<count).map { bucket in
            let start = bucket * waveform.count / count
            let end = max((bucket + 1) * waveform.count / count, start + 1)
            return waveform[start..<min(end, waveform.count)].max() ?? 0
        }
    }
}

// MARK: - Previews

struct WaveformView_Previews: PreviewProvider {
    static let waveform: [Float] = (0..<100).map { index in Float(abs(sin(Double(index) / 6))) * 0.9 + 0.1 }

    static var previews: some View {
        VStack(spacing: 12) {
            WaveformView(waveform: waveform)
            WaveformView(waveform: waveform, progress: 0.4)
            WaveformView(waveform: Array(repeating: 0, count: 30))
        }
        .frame(height: 120)
        .padding()
    }
}
