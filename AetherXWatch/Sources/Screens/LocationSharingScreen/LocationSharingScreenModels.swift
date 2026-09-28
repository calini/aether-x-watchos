//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

enum LiveShareDuration: CaseIterable {
    case fifteenMinutes
    case oneHour

    var duration: Duration {
        switch self {
        case .fifteenMinutes: .seconds(15 * 60)
        case .oneHour: .seconds(60 * 60)
        }
    }

    var title: String {
        switch self {
        case .fifteenMinutes: WatchStrings.shareLive15
        case .oneHour: WatchStrings.shareLive60
        }
    }
}

struct LocationSharingScreenViewState: BindableState {
    var authorization: LocationAuthorization
    var geoURI: GeoURI?
    /// `nil` while loading, and when MapKit couldn't draw one.
    var snapshot: UIImage?
    var snapshotFailed = false
    var isLocating = false
    /// No position within the timeout; offers Try again.
    var locateFailed = false
    /// Sending or starting a share, which can take a while just after launch.
    var isBusy = false
    /// Named in the confirmation before replacing a share running in another room.
    var otherShareRoomName: String?
    var bindings = LocationSharingScreenBindings()

    var canSendCurrent: Bool {
        authorization == .authorized && geoURI != nil && !isBusy
    }

    /// A live share doesn't need a first position: the service waits for one.
    var canShareLive: Bool {
        authorization == .authorized && !isBusy
    }
}

struct LocationSharingScreenBindings {
    /// The share awaiting confirmation to replace the one in another room.
    var confirmReplace: LiveShareDuration?
    var errorMessage: String?
}

enum LocationSharingScreenViewAction {
    case appear
    case tryAgain
    case sendCurrent
    case shareLive(LiveShareDuration)
    case confirmReplace
    case cancelReplace
}

enum LocationSharingScreenViewModelAction {
    case done
}
