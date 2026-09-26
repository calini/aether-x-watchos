//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

/// Pinned above a chat's messages while this device shares its live location there.
struct LiveLocationPill: View {
    let banner: LiveShareBanner
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            status
                .font(.footnote)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            StopLiveLocationButton(action: onStop)
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 4)
        .modifier(PillBackground())
    }

    @ViewBuilder
    private var status: some View {
        if banner.isPaused {
            Text(WatchStrings.liveLocationPaused)
        } else {
            // Ticks on the share's own minute boundaries, so the count drops exactly as each minute runs out.
            TimelineView(.periodic(from: countdownStart, by: 60)) { timeline in
                Text(WatchStrings.sharingLive(minutesLeft: banner.minutesLeft(at: timeline.date)))
            }
        }
    }

    /// A minute boundary of the share at or before now.
    private var countdownStart: Date {
        let minutesLeft = banner.minutesLeft(at: .now)
        return banner.endsAt.addingTimeInterval(-60 * Double(minutesLeft))
    }
}

/// A small glass Stop, for the pill and the user's own live bubble.
struct StopLiveLocationButton: View {
    let action: () -> Void

    var body: some View {
        Button(WatchStrings.stop, action: action)
            .buttonStyle(SmallGlassButtonStyle())
    }
}

private struct SmallGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(watchOS 26, *) {
            label(configuration)
                .foregroundStyle(Color.compound.textCriticalPrimary)
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            label(configuration)
                .foregroundStyle(Color.compound.textCriticalPrimary)
                .background(Color.compound.bgCriticalSubtle, in: Capsule())
                .opacity(configuration.isPressed ? 0.6 : 1)
        }
    }

    private func label(_ configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .contentShape(Capsule())
    }
}

private struct PillBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 26, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
        }
    }
}

// MARK: - Previews

struct LiveLocationPill_Previews: PreviewProvider {
    static var previews: some View {
        LiveLocationPill(banner: LiveShareBanner(endsAt: .now.addingTimeInterval(12 * 60), isPaused: false), onStop: { })
            .padding(.horizontal, 4)
            .previewDisplayName("Active")
        LiveLocationPill(banner: LiveShareBanner(endsAt: .now.addingTimeInterval(12 * 60), isPaused: true), onStop: { })
            .padding(.horizontal, 4)
            .previewDisplayName("Paused")
    }
}
