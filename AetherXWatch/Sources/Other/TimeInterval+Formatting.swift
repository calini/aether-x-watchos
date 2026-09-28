//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

extension TimeInterval {
    /// "m:ss", e.g. a voice message's length.
    func formattedMinutesSeconds(roundingUp: Bool = false) -> String {
        let seconds = Int(roundingUp ? rounded(.up) : rounded(.down))
        return Duration.seconds(max(seconds, 0)).formatted(.time(pattern: .minuteSecond))
    }
}
