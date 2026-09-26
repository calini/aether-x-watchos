//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementXWatch
import Foundation
import Testing

struct MapSnapshotLoaderTests {
    private let size = CGSize(width: 136, height: 90)

    @Test
    func keyRoundsToFourDecimalPlaces() {
        let key = MapSnapshotKey(geoURI: geo(51.50721, -0.12759), size: size)

        #expect(key == MapSnapshotKey(geoURI: geo(51.50719, -0.12761), size: size))
        #expect(key != MapSnapshotKey(geoURI: geo(51.50731, -0.12759), size: size))
        #expect(key != MapSnapshotKey(geoURI: geo(51.50721, -0.12749), size: size))
    }

    @Test
    func keyIgnoresUncertaintyButNotSize() {
        let key = MapSnapshotKey(geoURI: geo(51.5072, -0.1276), size: size)

        #expect(key == MapSnapshotKey(geoURI: GeoURI(latitude: 51.5072, longitude: -0.1276, uncertainty: 30), size: size))
        #expect(key != MapSnapshotKey(geoURI: geo(51.5072, -0.1276), size: CGSize(width: 200, height: 120)))
    }

    @Test
    func redrawsTheFirstPosition() {
        #expect(MapSnapshotLoader.shouldRedraw(from: nil, to: geo(51.5072, -0.1276)))
    }

    @Test
    func keepsTheLastDrawingWithoutANewPosition() {
        #expect(!MapSnapshotLoader.shouldRedraw(from: geo(51.5072, -0.1276), to: nil))
        #expect(!MapSnapshotLoader.shouldRedraw(from: nil, to: nil))
    }

    @Test
    func redrawsOnlyAfterMovingMoreThan25Metres() {
        let drawn = geo(51.5072, -0.1276)

        // 0.0001° of latitude is about 11 m.
        #expect(!MapSnapshotLoader.shouldRedraw(from: drawn, to: geo(51.5073, -0.1276)))
        #expect(!MapSnapshotLoader.shouldRedraw(from: drawn, to: geo(51.5074, -0.1276)))
        #expect(MapSnapshotLoader.shouldRedraw(from: drawn, to: geo(51.5075, -0.1276)))
        #expect(MapSnapshotLoader.shouldRedraw(from: drawn, to: geo(51.6, -0.1276)))
    }

    // MARK: - Helpers

    private func geo(_ latitude: Double, _ longitude: Double) -> GeoURI {
        GeoURI(latitude: latitude, longitude: longitude, uncertainty: nil)
    }
}
