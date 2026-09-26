//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementXWatch
import SwiftUI
import Testing

struct UIImageDownsampledTests {
    @Test
    func downsamplesALargeJPEGToTheMaxPixelSize() throws {
        let data = try #require(Self.makeImageData(width: 3000, height: 2000, jpeg: true))
        let image = try #require(UIImage.downsampled(from: data, maxPixelSize: 2048))
        #expect(max(image.size.width, image.size.height) <= 2048)
    }

    @Test
    func keepsAspectRatioWhenDownsamplingAPNG() throws {
        let data = try #require(Self.makeImageData(width: 3000, height: 1500, jpeg: false))
        let image = try #require(UIImage.downsampled(from: data, maxPixelSize: 1000))
        #expect(image.size.width == 1000)
        #expect(abs(image.size.width / image.size.height - 2) < 0.01)
    }

    @Test
    func doesNotUpscaleAnImageSmallerThanTheMaxPixelSize() throws {
        let data = try #require(Self.makeImageData(width: 200, height: 100, jpeg: false))
        let image = try #require(UIImage.downsampled(from: data, maxPixelSize: 2048))
        #expect(image.size == CGSize(width: 200, height: 100))
    }

    @Test
    func returnsNilForInvalidData() {
        #expect(UIImage.downsampled(from: Data([0x00, 0x01, 0x02]), maxPixelSize: 2048) == nil)
    }

    /// Renders a plain-colour image at an exact pixel size (scale 1), then encodes it.
    private static func makeImageData(width: CGFloat, height: CGFloat, jpeg: Bool) -> Data? {
        let renderer = ImageRenderer(content: Color.blue.frame(width: width, height: height))
        renderer.scale = 1
        guard let uiImage = renderer.uiImage else { return nil }
        return jpeg ? uiImage.jpegData(compressionQuality: 0.8) : uiImage.pngData()
    }
}
