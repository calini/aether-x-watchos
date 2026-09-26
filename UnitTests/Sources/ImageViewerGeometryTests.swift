//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementXWatch
import SwiftUI
import Testing

struct ImageViewerGeometryTests {
    private let container = CGSize(width: 200, height: 240)

    @Test
    func fitsLandscapeImageToWidth() {
        #expect(ImageViewerGeometry.fittedSize(of: CGSize(width: 1000, height: 500), in: container) == CGSize(width: 200, height: 100))
    }

    @Test
    func fitsPortraitImageToHeight() {
        #expect(ImageViewerGeometry.fittedSize(of: CGSize(width: 300, height: 600), in: container) == CGSize(width: 120, height: 240))
    }

    @Test
    func fitsEmptyImageToZero() {
        #expect(ImageViewerGeometry.fittedSize(of: .zero, in: container) == .zero)
    }

    @Test
    func centresImageAtNoZoom() {
        let offset = clampedOffset(CGSize(width: 50, height: -50), zoom: 1, fittedSize: CGSize(width: 200, height: 100))
        #expect(offset == .zero)
    }

    @Test
    func keepsOffsetWithinZoomedImage() {
        let offset = clampedOffset(CGSize(width: 30, height: -10), zoom: 2, fittedSize: CGSize(width: 200, height: 100))
        #expect(offset == CGSize(width: 30, height: 0))
    }

    @Test
    func clampsOffsetToEdges() {
        let fitted = CGSize(width: 200, height: 100)
        #expect(clampedOffset(CGSize(width: 500, height: 500), zoom: 4, fittedSize: fitted) == CGSize(width: 300, height: 80))
        #expect(clampedOffset(CGSize(width: -500, height: -500), zoom: 4, fittedSize: fitted) == CGSize(width: -300, height: -80))
    }

    @Test
    func reclampsOffsetWhenZoomingOut() {
        let fitted = CGSize(width: 200, height: 100)
        let zoomedIn = clampedOffset(CGSize(width: 300, height: 80), zoom: 4, fittedSize: fitted)
        #expect(clampedOffset(zoomedIn, zoom: 2, fittedSize: fitted) == CGSize(width: 100, height: 0))
        #expect(clampedOffset(zoomedIn, zoom: 1, fittedSize: fitted) == .zero)
    }

    @Test
    func clampsZoom() {
        #expect(ImageViewerGeometry.clampedZoom(0.5) == 1)
        #expect(ImageViewerGeometry.clampedZoom(2.5) == 2.5)
        #expect(ImageViewerGeometry.clampedZoom(6) == 4)
    }

    @Test
    func togglesZoom() {
        #expect(ImageViewerGeometry.toggledZoom(1) == 2)
        #expect(ImageViewerGeometry.toggledZoom(2) == 1)
        #expect(ImageViewerGeometry.toggledZoom(3.5) == 1)
    }

    private func clampedOffset(_ offset: CGSize, zoom: CGFloat, fittedSize: CGSize) -> CGSize {
        ImageViewerGeometry.clampedOffset(offset, zoom: zoom, fittedSize: fittedSize, containerSize: container)
    }
}
