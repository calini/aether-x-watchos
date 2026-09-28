//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct ImageThumbnail: View {
    /// Full sharpness at the viewer's 4× max zoom, while keeping a 12 MP original's decode under ~12 MB.
    /// `nonisolated` so the background decode task (off the main actor) can read it directly.
    private nonisolated static let fullScreenMaxPixelSize: CGFloat = 2048

    let image: ImageBody

    @Environment(\.mediaLoader) private var mediaLoader
    @State private var uiImage: UIImage?
    @State private var isShowingFullScreen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Group {
                if let uiImage {
                    Image(uiImage: uiImage).resizable().scaledToFit()
                } else {
                    Rectangle().fill(Color.compound.bgSubtleSecondary)
                        .aspectRatio(image.aspectRatio ?? 1, contentMode: .fit)
                        .overlay { ProgressView() }
                }
            }
            .frame(maxWidth: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture { if uiImage != nil { isShowingFullScreen = true } }
            if let caption = image.caption {
                Text(caption).font(.footnote)
            }
        }
        .task(id: image.source) {
            if let data = await mediaLoader.loadThumbnail(image.thumbnailSource ?? image.source, 300, 300) {
                uiImage = UIImage(data: data)
            }
        }
        .fullScreenCover(isPresented: $isShowingFullScreen) {
            if let uiImage {
                ImageViewer(image: uiImage, caption: image.caption) { [mediaLoader, source = image.source] in
                    guard let data = await mediaLoader.loadContent(source) else { return nil }
                    // Decoding a full-size original is CPU-heavy, so it's kept off the main actor.
                    return await Task.detached {
                        UIImage.downsampled(from: data, maxPixelSize: Self.fullScreenMaxPixelSize)
                    }.value
                }
            }
        }
        .accessibilityLabel(image.caption ?? WatchStrings.photoAccessibilityLabel)
    }
}
