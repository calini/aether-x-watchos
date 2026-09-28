//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import AVFoundation
@testable import AetherXWatch
import Testing

struct AudioSessionProxyTests {
    @Test
    func mapsTheRecordPermission() {
        #expect(MicrophonePermission(.undetermined) == .undetermined)
        #expect(MicrophonePermission(.denied) == .denied)
        #expect(MicrophonePermission(.granted) == .granted)
    }
}
