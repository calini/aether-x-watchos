//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// A parsed `geo:` URI (RFC 5870 subset): coordinates plus an optional `u=` uncertainty, in metres.
struct GeoURI: Equatable {
    let latitude: Double
    let longitude: Double
    let uncertainty: Double?

    init(latitude: Double, longitude: Double, uncertainty: Double?) {
        self.latitude = latitude
        self.longitude = longitude
        self.uncertainty = uncertainty
    }

    init?(string: String) {
        guard string.hasPrefix("geo:") else { return nil }

        let components = string.dropFirst("geo:".count).split(separator: ";", omittingEmptySubsequences: false)
        guard let coordinates = components.first, !coordinates.isEmpty else { return nil }

        // "lat,lon" or "lat,lon,altitude" — altitude is parsed but not kept.
        let parts = coordinates.split(separator: ",")
        guard parts.count == 2 || parts.count == 3,
              let latitude = Double(parts[0]), (-90...90).contains(latitude),
              let longitude = Double(parts[1]), (-180...180).contains(longitude) else { return nil }

        var uncertainty: Double?
        for parameter in components.dropFirst() where parameter.hasPrefix("u=") {
            uncertainty = Double(parameter.dropFirst(2))
        }

        self.init(latitude: latitude, longitude: longitude, uncertainty: uncertainty)
    }

    var string: String {
        let coordinates = "geo:\(Self.decimalString(latitude)),\(Self.decimalString(longitude))"
        guard let uncertainty else { return coordinates }
        return "\(coordinates);u=\(Int(uncertainty))"
    }

    /// Fixed-point with up to 6 decimals (~0.1 m): interpolating a `Double` prints e.g. `-5e-05`, which
    /// isn't valid in a geo URI. `String(format:)` without a locale always uses a "." separator.
    private static func decimalString(_ value: Double) -> String {
        var string = String(format: "%.6f", value)
        if string.contains(".") {
            while string.hasSuffix("0") {
                string.removeLast()
            }
            if string.hasSuffix(".") {
                string.removeLast()
            }
        }
        return string == "-0" ? "0" : string
    }
}
