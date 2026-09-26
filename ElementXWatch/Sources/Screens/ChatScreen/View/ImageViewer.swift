//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

/// Full-screen image with Digital Crown zoom, drag to pan and double-tap to zoom.
struct ImageViewer: View {
    let caption: String?
    /// Loads a sharper image to replace the initial one; `nil` keeps the initial one.
    let loadLargeImage: () async -> UIImage?

    @State private var uiImage: UIImage
    @State private var zoom: CGFloat
    @State private var offset = CGSize.zero
    @State private var dragStartOffset: CGSize?
    @FocusState private var isFocused: Bool

    init(image: UIImage, caption: String?, initialZoom: CGFloat = 1, loadLargeImage: @escaping () async -> UIImage?) {
        self.caption = caption
        self.loadLargeImage = loadLargeImage
        _uiImage = State(initialValue: image)
        _zoom = State(initialValue: ImageViewerGeometry.clampedZoom(initialZoom))
    }

    var body: some View {
        GeometryReader { proxy in
            let fittedSize = ImageViewerGeometry.fittedSize(of: uiImage.size, in: proxy.size)
            Image(uiImage: uiImage)
                .resizable()
                .frame(width: fittedSize.width, height: fittedSize.height)
                .scaleEffect(zoom)
                .offset(offset)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
                .gesture(dragGesture(fittedSize: fittedSize, containerSize: proxy.size), including: zoom > 1 ? .all : .subviews)
                .onTapGesture(count: 2) {
                    withAnimation { zoom = ImageViewerGeometry.toggledZoom(zoom) }
                }
                .onChange(of: zoom) {
                    offset = ImageViewerGeometry.clampedOffset(offset, zoom: zoom, fittedSize: fittedSize, containerSize: proxy.size)
                }
        }
        .ignoresSafeArea()
        .background(Color.black.ignoresSafeArea())
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .digitalCrownRotation($zoom,
                              from: ImageViewerGeometry.zoomRange.lowerBound,
                              through: ImageViewerGeometry.zoomRange.upperBound,
                              by: 0.1,
                              sensitivity: .low,
                              isContinuous: false,
                              isHapticFeedbackEnabled: true)
        .accessibilityElement()
        .accessibilityLabel(caption ?? WatchStrings.photoAccessibilityLabel)
        .accessibilityAddTraits(.isImage)
        .onAppear { isFocused = true }
        .task {
            if let largeImage = await loadLargeImage() {
                uiImage = largeImage
            }
        }
    }

    private func dragGesture(fittedSize: CGSize, containerSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let start = dragStartOffset ?? offset
                dragStartOffset = start
                let proposed = CGSize(width: start.width + value.translation.width, height: start.height + value.translation.height)
                offset = ImageViewerGeometry.clampedOffset(proposed, zoom: zoom, fittedSize: fittedSize, containerSize: containerSize)
            }
            .onEnded { _ in dragStartOffset = nil }
    }
}

struct ImageViewer_Previews: PreviewProvider {
    static var previews: some View {
        ImageViewer(image: makeImage(width: 400, height: 250), caption: "Landscape", loadLargeImage: { nil })
            .previewDisplayName("Landscape")
        ImageViewer(image: makeImage(width: 250, height: 400), caption: nil, loadLargeImage: { nil })
            .previewDisplayName("Portrait")
        ImageViewer(image: makeImage(width: 400, height: 250), caption: nil, initialZoom: 2, loadLargeImage: { nil })
            .previewDisplayName("Zoomed")
    }

    static func makeImage(width: CGFloat, height: CGFloat) -> UIImage {
        let content = LinearGradient(colors: [.purple, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay { Image(systemName: "mountain.2.fill").resizable().scaledToFit().padding(40).foregroundStyle(.white) }
            .frame(width: width, height: height)
        return ImageRenderer(content: content).uiImage ?? UIImage()
    }
}
