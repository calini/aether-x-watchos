//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import MatrixRustSDK
import SwiftUI

/// Initials in a coloured circle, replaced by the thumbnail once it loads.
struct AvatarView: View {
    let name: String
    let mxcURL: URL?
    let size: CGFloat

    @Environment(\.mediaLoader) private var mediaLoader
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Circle().fill(Color.compound.bgAccentRest)
            Text(initials).font(.system(size: size * 0.45, weight: .semibold)).foregroundStyle(.white)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
        .task(id: mxcURL) { await loadImage() }
    }

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first(where: \.isLetter) }
        return letters.isEmpty ? "#" : String(letters).uppercased()
    }

    private func loadImage() async {
        guard let mxcURL, let source = try? MediaSource.fromUrl(url: mxcURL.absoluteString) else { return }
        let pixels = Int(size * displayScale)
        if let data = await mediaLoader.loadThumbnail(MediaSourceProxy(source: source), pixels, pixels) {
            image = UIImage(data: data)
        }
    }
}
