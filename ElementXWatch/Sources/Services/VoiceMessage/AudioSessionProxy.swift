//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation

enum MicrophonePermission: Equatable {
    case undetermined
    case denied
    case granted
}

// sourcery: AutoMockable
protocol AudioSessionProxyProtocol: AnyObject {
    var recordPermission: MicrophonePermission { get }
    /// Prompts the first time; afterwards answers with the stored choice.
    func requestRecordPermission() async -> Bool
    func activateForRecording() throws
    func activateForPlayback() throws
    func deactivate()
}

extension MicrophonePermission {
    init(_ permission: AVAudioApplication.recordPermission) {
        switch permission {
        case .undetermined: self = .undetermined
        case .granted: self = .granted
        case .denied: self = .denied
        @unknown default: self = .denied
        }
    }
}

final class AudioSessionProxy: AudioSessionProxyProtocol {
    private let session = AVAudioSession.sharedInstance()

    var recordPermission: MicrophonePermission {
        MicrophonePermission(AVAudioApplication.shared.recordPermission)
    }

    func requestRecordPermission() async -> Bool {
        let isGranted = await AVAudioApplication.requestRecordPermission()
        MXLog.info("Microphone permission \(isGranted ? "granted" : "denied")")
        return isGranted
    }

    func activateForRecording() throws {
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)
    }

    func activateForPlayback() throws {
        try session.setCategory(.playback, mode: .default, policy: .default)
        try session.setActive(true)
    }

    func deactivate() {
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            MXLog.error("Deactivating the audio session failed")
        }
    }
}
