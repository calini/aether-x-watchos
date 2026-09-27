//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

struct VoiceRecordingScreenCoordinatorParameters {
    let recorder: VoiceMessageRecorderProtocol
    let timelineProxy: TimelineProxyProtocol
    let audioSession: AudioSessionProxyProtocol
}

enum VoiceRecordingScreenCoordinatorAction {
    /// Sent: close the Attachments sheet.
    case done
    /// Discarded: back to the Attachments sheet.
    case cancelled
}

final class VoiceRecordingScreenCoordinator: CoordinatorProtocol {
    private let viewModel: VoiceRecordingScreenViewModel
    private let actionsSubject = PassthroughSubject<VoiceRecordingScreenCoordinatorAction, Never>()
    private var cancellables = Set<AnyCancellable>()

    var actionsPublisher: AnyPublisher<VoiceRecordingScreenCoordinatorAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }

    init(parameters: VoiceRecordingScreenCoordinatorParameters) {
        let timelineProxy = parameters.timelineProxy
        viewModel = VoiceRecordingScreenViewModel(recorder: parameters.recorder,
                                                  encode: Self.encodeInBackground,
                                                  send: { await timelineProxy.sendVoiceMessage(fileURL: $0.fileURL, duration: $0.duration, waveform: $1) },
                                                  previewPlayer: VoiceMessagePreviewPlayer(audioSession: parameters.audioSession))
    }

    func start() {
        viewModel.actionsPublisher
            .sink { [weak self] action in
                switch action {
                case .done: self?.actionsSubject.send(.done)
                case .cancelled: self?.actionsSubject.send(.cancelled)
                }
            }
            .store(in: &cancellables)
    }

    func toPresentable() -> AnyView {
        AnyView(VoiceRecordingScreen(context: viewModel.context))
    }

    private static func encodeInBackground(_ url: URL) async -> Result<EncodedVoiceMessage, OpusCodecError> {
        await Task.detached {
            do throws(OpusCodecError) {
                return try .success(VoiceMessageEncoder.encode(recordingAt: url))
            } catch {
                return .failure(error)
            }
        }.value
    }
}
