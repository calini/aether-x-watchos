//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

/// Zoom and pan maths for `ImageViewer`.
enum ImageViewerGeometry {
    static let zoomRange: ClosedRange<CGFloat> = 1...4
    static let doubleTapZoom: CGFloat = 2

    /// The size of an image aspect-fitted into the container.
    static func fittedSize(of imageSize: CGSize, in containerSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    /// Limits the offset so the zoomed image never leaves an edge of the container uncovered
    /// (or stays centred along an axis where it's smaller than the container).
    static func clampedOffset(_ offset: CGSize, zoom: CGFloat, fittedSize: CGSize, containerSize: CGSize) -> CGSize {
        let maxX = max(0, (fittedSize.width * zoom - containerSize.width) / 2)
        let maxY = max(0, (fittedSize.height * zoom - containerSize.height) / 2)
        return CGSize(width: min(max(offset.width, -maxX), maxX),
                      height: min(max(offset.height, -maxY), maxY))
    }

    static func clampedZoom(_ zoom: CGFloat) -> CGFloat {
        min(max(zoom, zoomRange.lowerBound), zoomRange.upperBound)
    }

    static func toggledZoom(_ zoom: CGFloat) -> CGFloat {
        zoom > zoomRange.lowerBound ? zoomRange.lowerBound : doubleTapZoom
    }
}
