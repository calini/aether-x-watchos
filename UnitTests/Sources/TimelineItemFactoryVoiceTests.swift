//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import AetherXWatch
import Foundation
import MatrixRustSDK
import Testing

struct TimelineItemFactoryVoiceTests {
    @Test
    func mapsAVoiceMessageWithANormalisedWaveform() throws {
        let content = try audioContent(audio: UnstableAudioDetailsContent(duration: 3, waveform: [0, 256, 1024, 2000]), isVoice: true)

        let body = TimelineItemFactory.body(for: content)

        #expect(body == .voice(VoiceBody(duration: 3, waveform: [0, 0.25, 1, 1], source: try source())))
    }

    @Test
    func aVoiceMessageWithoutDetailsFallsBackToItsInfo() throws {
        let content = try audioContent(info: AudioInfo(duration: 7, size: nil, mimetype: "audio/ogg"), isVoice: true)

        #expect(TimelineItemFactory.body(for: content) == .voice(VoiceBody(duration: 7, waveform: [], source: try source())))
    }

    @Test
    func aVoiceMessageWithNoDurationIsZeroLong() throws {
        let content = try audioContent(isVoice: true)

        #expect(TimelineItemFactory.body(for: content) == .voice(VoiceBody(duration: 0, waveform: [], source: try source())))
    }

    @Test
    func plainAudioStaysUnsupported() throws {
        let content = try audioContent(audio: UnstableAudioDetailsContent(duration: 3, waveform: [512]), isVoice: false)

        #expect(TimelineItemFactory.body(for: content) == .unsupported(WatchStrings.audio))
    }

    @Test
    func voiceMessagesHaveARoomSummaryPreview() throws {
        #expect(RoomSummaryPreview.text(for: try audioContent(isVoice: true)) == "🎤 \(WatchStrings.voiceMessage)")
        #expect(RoomSummaryPreview.text(for: try audioContent(isVoice: false)) == WatchStrings.audio)
    }

    // MARK: - Helpers

    private func audioContent(info: AudioInfo? = nil, audio: UnstableAudioDetailsContent? = nil, isVoice: Bool) throws -> TimelineItemContent {
        let content = try AudioMessageContent(filename: "voice.ogg", caption: nil, formattedCaption: nil, source: mediaSource(),
                                               info: info, audio: audio, voice: isVoice ? UnstableVoiceContent() : nil)
        return messageContent(.audio(content: content))
    }

    private func source() throws -> MediaSourceProxy {
        try MediaSourceProxy(source: mediaSource())
    }

    private func mediaSource() throws -> MediaSource {
        try MediaSource.fromUrl(url: "mxc://example.org/voice")
    }
}
