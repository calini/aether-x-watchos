//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import CompoundDesignTokens
import SwiftUI

/// A voice message: a play button, its waveform filling with progress, and the time.
struct VoiceMessageBubble: View {
    private static let placeholderWaveform = [Float](repeating: 0.3, count: 30)

    let voice: VoiceBody
    /// This message's playback (`ChatScreenViewState.voicePlayback(for:)`).
    let playback: VoicePlaybackState
    let onTogglePlayback: () -> Void

    private var isFailed: Bool {
        if case .failed = playback { true } else { false }
    }

    private var progress: Double {
        switch playback {
        case .playing(_, let progress, _), .paused(_, let progress, _): progress
        case .idle, .preparing, .failed: 0
        }
    }

    /// The total length until it plays, then the time played.
    private var time: String {
        switch playback {
        case .playing(_, _, let elapsed), .paused(_, _, let elapsed): elapsed.formattedMinutesSeconds()
        case .idle, .preparing, .failed: voice.duration.formattedMinutesSeconds(roundingUp: true)
        }
    }

    private var accessibilityValue: String {
        switch playback {
        case .idle: ""
        case .preparing: WatchStrings.loading
        case .playing: WatchStrings.playing
        case .paused: WatchStrings.paused
        case .failed: WatchStrings.playVoiceMessageFailed
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onTogglePlayback) { buttonIcon }
                .buttonStyle(CircleGlassButtonStyle(size: 30, iconColor: isFailed ? Color.compound.iconCriticalPrimary : Color.compound.iconPrimary))
            VStack(alignment: .leading, spacing: 2) {
                WaveformView(waveform: voice.waveform.isEmpty ? Self.placeholderWaveform : voice.waveform, progress: progress)
                    .frame(width: 88, height: 20)
                Text(time)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.compound.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WatchStrings.voiceMessage(duration: voice.duration.formattedMinutesSeconds(roundingUp: true)))
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onTogglePlayback)
    }

    @ViewBuilder
    private var buttonIcon: some View {
        switch playback {
        case .preparing:
            ProgressView()
        case .playing:
            icon(\.pauseSolid)
        case .failed:
            icon(\.errorSolid)
        case .idle, .paused:
            icon(\.playSolid)
        }
    }

    private func icon(_ keyPath: KeyPath<CompoundIcons, Image>) -> some View {
        Image(compound: keyPath)
            .resizable()
            .scaledToFit()
            .frame(width: 14, height: 14)
    }
}

// MARK: - Previews

struct VoiceMessageBubble_Previews: PreviewProvider {
    static let voice = VoiceBody(duration: 12.4,
                                 waveform: (0..<100).map { index in Float(abs(sin(Double(index) / 5))) * 0.8 + 0.1 },
                                 source: MediaSourceProxy(url: "mxc://example.org/voice")!)

    static var previews: some View {
        bubble(.idle)
            .previewDisplayName("Idle")
        bubble(.preparing(id: "$1"))
            .previewDisplayName("Preparing")
        bubble(.playing(id: "$1", progress: 0.4, elapsed: 5))
            .previewDisplayName("Playing")
        bubble(.paused(id: "$1", progress: 0.4, elapsed: 5))
            .previewDisplayName("Paused")
        bubble(.failed(id: "$1"))
            .previewDisplayName("Failed")
        bubble(.idle, voice: VoiceBody(duration: 3, waveform: [], source: voice.source))
            .previewDisplayName("No waveform")
    }

    static func bubble(_ playback: VoicePlaybackState, voice: VoiceBody = voice) -> some View {
        VoiceMessageBubble(voice: voice, playback: playback) { }
            .padding(8)
            .background(Color.compound.bgBubbleIncoming, in: RoundedRectangle(cornerRadius: 12))
    }
}
