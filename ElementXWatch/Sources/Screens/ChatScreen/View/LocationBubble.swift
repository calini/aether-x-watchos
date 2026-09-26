//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

/// A map preview for a one-off location or a live share. Tapping it opens the full-screen map.
struct LocationBubble: View {
    enum Content: Equatable {
        case location(LocationBody)
        case live(LiveLocationBubbleState)
    }

    static let snapshotSize = CGSize(width: 136, height: 90)

    let content: Content
    let onTap: () -> Void
    /// Offers Stop, for the user's own running live share.
    var onStop: (() -> Void)?

    @Environment(\.mapSnapshotLoader) private var mapSnapshotLoader
    /// Where the snapshot was taken: a live share only moves it once its sender has moved noticeably.
    @State private var drawnGeoURI: GeoURI?
    @State private var snapshot: UIImage?
    @State private var snapshotFailed = false

    private var geoURI: GeoURI? {
        switch content {
        case .location(let body): body.geoURI
        case .live(let state): state.geoURI
        }
    }

    private var isLiveShare: Bool {
        if case .live = content { true } else { false }
    }

    private var snapshotKey: MapSnapshotKey? {
        drawnGeoURI.map { MapSnapshotKey(geoURI: $0, size: Self.snapshotSize) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                preview
                    .frame(width: Self.snapshotSize.width, height: Self.snapshotSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTap)
                    .accessibilityLabel(isLiveShare ? WatchStrings.liveLocation : WatchStrings.location)
                caption
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            // Outside the combined element, so VoiceOver reaches it as its own button.
            if let onStop {
                StopLiveLocationButton(action: onStop)
                    .frame(width: Self.snapshotSize.width)
            }
        }
        .onChange(of: geoURI, initial: true) {
            if MapSnapshotLoader.shouldRedraw(from: drawnGeoURI, to: geoURI) {
                drawnGeoURI = geoURI
            }
        }
        .task(id: snapshotKey) {
            guard let mapSnapshotLoader, geoURI != nil else {
                snapshotFailed = true
                return
            }
            // This can run before `onChange` sets the first drawn position; that change re-runs it.
            guard let drawnGeoURI else { return }

            // The previous image stays up while a live share's next one loads.
            if let image = await mapSnapshotLoader.snapshot(of: drawnGeoURI, size: Self.snapshotSize) {
                snapshot = image
                snapshotFailed = false
            } else if snapshot == nil, !Task.isCancelled {
                snapshotFailed = true
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let snapshot {
            Image(uiImage: snapshot).resizable()
        } else if snapshotFailed {
            placeholder
        } else {
            Rectangle().fill(Color.compound.bgSubtleSecondary).overlay { ProgressView() }
        }
    }

    /// Shown when there's no position or MapKit couldn't draw one; the coordinates are never logged.
    private var placeholder: some View {
        Rectangle()
            .fill(Color.compound.bgSubtleSecondary)
            .overlay {
                VStack(spacing: 2) {
                    Text(WatchStrings.locationPlaceholderIcon).font(.title3)
                    if let geoURI {
                        Text(String(format: "%.3f, %.3f", geoURI.latitude, geoURI.longitude))
                            .font(.caption2)
                            .foregroundStyle(Color.compound.textSecondary)
                    }
                }
            }
    }

    @ViewBuilder
    private var caption: some View {
        switch content {
        case .location(let body):
            if let description = body.description, !description.isEmpty {
                Text(description).font(.footnote)
            }
        case .live(let state):
            liveStatus(state).font(.footnote).foregroundStyle(Color.compound.textSecondary)
        }
    }

    @ViewBuilder
    private func liveStatus(_ state: LiveLocationBubbleState) -> some View {
        if !state.isLive {
            Text(WatchStrings.liveLocationEnded)
        } else if let lastUpdate = state.lastUpdate {
            TimelineView(.periodic(from: .now, by: 10)) { timeline in
                Text(WatchStrings.liveUpdated(secondsAgo: Int(timeline.date.timeIntervalSince(lastUpdate))))
            }
        } else {
            Text(WatchStrings.live)
        }
    }
}

// MARK: - Previews

struct LocationBubble_Previews: PreviewProvider {
    static let geoURI = GeoURI(latitude: 51.5072, longitude: -0.1276, uncertainty: nil)
    static let loader = MapSnapshotLoader()

    static var previews: some View {
        bubble(.location(LocationBody(geoURI: geoURI, description: "Trafalgar Square", body: "")))
            .previewDisplayName("Location")
        bubble(.location(LocationBody(geoURI: geoURI, description: nil, body: "")), loader: nil)
            .previewDisplayName("Location, no snapshot")
        bubble(.location(LocationBody(geoURI: nil, description: nil, body: "")), loader: nil)
            .previewDisplayName("Location, unreadable")
        bubble(.live(LiveLocationBubbleState(isLive: true, geoURI: geoURI, lastUpdate: .now.addingTimeInterval(-30), endDate: .now.addingTimeInterval(600))))
            .previewDisplayName("Live")
        bubble(.live(LiveLocationBubbleState(isLive: false, geoURI: geoURI, lastUpdate: .now.addingTimeInterval(-600), endDate: .now)))
            .previewDisplayName("Live, ended")
        bubble(.live(LiveLocationBubbleState(isLive: true, geoURI: geoURI, lastUpdate: .now, endDate: .now.addingTimeInterval(600))), isOwn: true)
            .previewDisplayName("Own live")
        bubble(.live(LiveLocationBubbleState(isLive: true, geoURI: geoURI, lastUpdate: .now, endDate: .now.addingTimeInterval(600))), isOwn: true, onStop: { })
            .previewDisplayName("Own live, sharing from this watch")
    }

    static func bubble(_ content: LocationBubble.Content, isOwn: Bool = false, loader: MapSnapshotLoaderProtocol? = loader,
                       onStop: (() -> Void)? = nil) -> some View {
        LocationBubble(content: content, onTap: { }, onStop: onStop)
            .padding(8)
            .background(isOwn ? Color.compound.bgBubbleOutgoing : Color.compound.bgBubbleIncoming, in: RoundedRectangle(cornerRadius: 12))
            .environment(\.mapSnapshotLoader, loader)
    }
}
