//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementXWatch
import SwiftUI
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

    @Test
    func concurrentRequestsForOneKeyShareARender() async throws {
        let renderer = TestRenderer()
        let gate = AsyncGate()
        let loader = MapSnapshotLoader(render: renderer.render(waitingFor: gate))

        let first = Task { await loader.snapshot(of: geo(51.50721, -0.1276), size: size) }
        let second = Task { await loader.snapshot(of: geo(51.50719, -0.1276), size: size) }
        try await waitUntil { renderer.count == 1 }
        await gate.open()

        let firstImage = await first.value
        let secondImage = await second.value
        #expect(firstImage != nil)
        #expect(firstImage === secondImage)
        #expect(renderer.count == 1)
    }

    @Test
    func rendersAtMostTwoAtATime() async throws {
        let renderer = TestRenderer()
        let gate = AsyncGate()
        let loader = MapSnapshotLoader(render: renderer.render(waitingFor: gate))

        let tasks = [51.1, 51.2, 51.3].map { latitude in Task { await loader.snapshot(of: geo(latitude, 0), size: size) } }
        try await waitUntil { renderer.count == 2 }
        for _ in 0..<20 { await Task.yield() }
        #expect(renderer.count == 2)

        await gate.open()
        for task in tasks {
            _ = await task.value
        }
        #expect(renderer.count == 3)
    }

    @Test
    func aCancelledRequestDoesNotRender() async {
        let renderer = TestRenderer()
        let loader = MapSnapshotLoader(render: renderer.render(waitingFor: nil))

        let task = Task { await loader.snapshot(of: geo(51.5, 0), size: size) }
        task.cancel()

        #expect(await task.value == nil)
        #expect(renderer.count == 0)
    }

    @Test
    func theCacheEvictsTheLeastRecentlyUsedImage() async {
        let renderer = TestRenderer()
        let loader = MapSnapshotLoader(cacheLimit: 2, render: renderer.render(waitingFor: nil))
        let (a, b, c) = (geo(51.1, 0), geo(51.2, 0), geo(51.3, 0))

        _ = await loader.snapshot(of: a, size: size)
        _ = await loader.snapshot(of: b, size: size)
        _ = await loader.snapshot(of: a, size: size) // A is now more recent than B.
        _ = await loader.snapshot(of: c, size: size) // Evicts B.
        _ = await loader.snapshot(of: a, size: size)
        _ = await loader.snapshot(of: b, size: size)

        #expect(renderer.latitudes == [51.1, 51.2, 51.3, 51.2])
    }

    @Test
    func failuresAreNotCached() async {
        let renderer = TestRenderer(fails: true)
        let loader = MapSnapshotLoader(render: renderer.render(waitingFor: nil))

        #expect(await loader.snapshot(of: geo(51.5, 0), size: size) == nil)
        #expect(await loader.snapshot(of: geo(51.5, 0), size: size) == nil)
        #expect(renderer.count == 2)
    }

    // MARK: - Helpers

    private func geo(_ latitude: Double, _ longitude: Double) -> GeoURI {
        GeoURI(latitude: latitude, longitude: longitude, uncertainty: nil)
    }
}

/// Counts renders and can hold them open until a gate opens.
private final class TestRenderer {
    private let fails: Bool
    private(set) var latitudes: [Double] = []

    var count: Int { latitudes.count }

    init(fails: Bool = false) {
        self.fails = fails
    }

    func render(waitingFor gate: AsyncGate?) -> MapSnapshotLoader.Render {
        { [self] geoURI, _ in
            latitudes.append(geoURI.latitude)
            await gate?.wait()
            return fails ? nil : UIImage()
        }
    }
}
