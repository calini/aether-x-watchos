//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum VoiceRecordingStep: Equatable {
    /// Waiting for the microphone: the permission prompt, then the recorder starting.
    case starting
    case permissionDenied
    /// `level` is the input level in 0…1.
    case recording(elapsed: TimeInterval, level: Float, isNearLimit: Bool)
    case preparing
    case review(EncodedVoiceMessage, waveform: [Float])
    case sending
}

struct VoiceRecordingScreenViewState: BindableState {
    var step: VoiceRecordingStep = .starting
    var isPlaying = false
    /// In 0…1.
    var playbackProgress: Double = 0
    var bindings = VoiceRecordingScreenBindings()

    /// Counts down while playing.
    var remainingPlaybackTime: TimeInterval? {
        guard case let .review(message, _) = step else { return nil }
        return message.duration * (1 - playbackProgress)
    }
}

struct VoiceRecordingScreenBindings {
    var errorMessage: String?
    /// The error alert offers Try again, for a failed send.
    var canRetrySend = false
}

enum VoiceRecordingScreenViewAction {
    case appear
    case stop
    case togglePlayback
    case send
    case retrySend
    /// Discards the recording and goes back to the Attachments sheet.
    case delete
    /// The screen went away (✕, back, or the sheet closing): discards the recording.
    case dismiss
}

enum VoiceRecordingScreenViewModelAction {
    /// Sent: the Attachments sheet closes.
    case done
    /// Discarded: back to the Attachments sheet.
    case cancelled
}
