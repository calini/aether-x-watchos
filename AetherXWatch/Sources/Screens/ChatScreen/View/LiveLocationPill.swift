//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
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
                .font(.caption2)
                // The countdown stays on one line; the longer paused copy may wrap rather than truncate.
                .lineLimit(banner.isPaused ? 2 : 1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onStop) {
                Image(compound: \.stopSolid)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(RoundStopButtonStyle())
            .accessibilityLabel(WatchStrings.stop)
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
            TimelineView(.periodic(from: banner.countdownStart(at: .now), by: 60)) { timeline in
                Text(WatchStrings.sharingLive(minutesLeft: banner.minutesLeft(at: timeline.date)))
            }
        }
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

private struct RoundStopButtonStyle: ButtonStyle {
    private static let size: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        if #available(watchOS 26, *) {
            label(configuration)
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            label(configuration)
                .background(Color.compound.bgCriticalSubtle, in: Circle())
                .opacity(configuration.isPressed ? 0.6 : 1)
        }
    }

    private func label(_ configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.compound.iconCriticalPrimary)
            .frame(width: Self.size, height: Self.size)
            .contentShape(Circle())
    }
}

/// Opaque under the glass: messages scroll beneath the pill and would otherwise show through its text.
private struct PillBackground: ViewModifier {
    func body(content: Content) -> some View {
        let backing = Capsule().fill(Color.compound.bgCanvasDefault.opacity(0.9))
        if #available(watchOS 26, *) {
            content
                .glassEffect(.regular, in: .capsule)
                .background(backing)
        } else {
            content.background(.ultraThinMaterial, in: Capsule()).background(backing)
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
