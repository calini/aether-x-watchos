//
// Copyright 2026 Calin Ilie.
//
// SPDX-License-Identifier: AGPL-3.0-only.
// Please see LICENSE files in the repository root for full details.
//

import CoreLocation
import MapKit
import SwiftUI

// sourcery: AutoMockable
protocol MapSnapshotLoaderProtocol: AnyObject {
    /// A map around the point with a pin on it, or `nil` if MapKit couldn't render one.
    func snapshot(of geoURI: GeoURI, size: CGSize) async -> UIImage?
}

/// Rounds to 4 decimal places (~11 m) plus the size, so positions that barely differ share one image.
struct MapSnapshotKey: Hashable {
    private let latitude: Double
    private let longitude: Double
    private let width: Double
    private let height: Double

    init(geoURI: GeoURI, size: CGSize) {
        latitude = (geoURI.latitude * 10000).rounded() / 10000
        longitude = (geoURI.longitude * 10000).rounded() / 10000
        width = size.width
        height = size.height
    }
}

final class MapSnapshotLoader: MapSnapshotLoaderProtocol {
    typealias Render = (GeoURI, CGSize) async -> UIImage?

    /// A live bubble only redraws after its sender has moved this far.
    private static let redrawDistance: CLLocationDistance = 25
    private static let regionDistance: CLLocationDistance = 500
    private static let pinSize: CGFloat = 24

    private let cacheLimit: Int
    private let maxConcurrentRenders: Int
    private let render: Render
    private var cache: [MapSnapshotKey: UIImage] = [:]
    /// Least recently used first.
    private var cacheOrder: [MapSnapshotKey] = []
    /// Requests for a key that is already rendering wait for that render instead of starting another.
    private var inFlight: [MapSnapshotKey: Task<UIImage?, Never>] = [:]
    private var activeRenders = 0
    private var renderSlotWaiters: [CheckedContinuation<Void, Never>] = []

    /// `render` is injectable so tests don't need MapKit.
    init(cacheLimit: Int = 30, maxConcurrentRenders: Int = 2, render: @escaping Render = MapSnapshotLoader.renderWithMapKit) {
        self.cacheLimit = cacheLimit
        self.maxConcurrentRenders = maxConcurrentRenders
        self.render = render
    }

    /// Whether a live bubble drawn at `drawn` should redraw for `latest`: only once it has moved noticeably.
    static func shouldRedraw(from drawn: GeoURI?, to latest: GeoURI?) -> Bool {
        guard let latest else { return false }
        guard let drawn else { return true }
        return CLLocation(latitude: drawn.latitude, longitude: drawn.longitude)
            .distance(from: CLLocation(latitude: latest.latitude, longitude: latest.longitude)) > redrawDistance
    }

    func snapshot(of geoURI: GeoURI, size: CGSize) async -> UIImage? {
        let key = MapSnapshotKey(geoURI: geoURI, size: size)
        if let image = cachedImage(for: key) {
            return image
        }
        if let task = inFlight[key] {
            return await task.value
        }

        await acquireRenderSlot()
        defer { releaseRenderSlot() }

        // Waiting for a slot let other requests run: one may have rendered this key, or the bubble may have gone.
        if let image = cachedImage(for: key) {
            return image
        }
        if let task = inFlight[key] {
            return await task.value
        }
        guard !Task.isCancelled else { return nil }

        let task = Task { await render(geoURI, size) }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image {
            store(image, for: key)
        }
        return image
    }

    static func renderWithMapKit(_ geoURI: GeoURI, size: CGSize) async -> UIImage? {
        let coordinate = CLLocationCoordinate2D(latitude: geoURI.latitude, longitude: geoURI.longitude)
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: regionDistance, longitudinalMeters: regionDistance)
        options.size = size
        options.scale = 2

        do {
            let snapshot = try await MKMapSnapshotter(options: options).start()
            return drawPin(on: snapshot.image, at: snapshot.point(for: coordinate))
        } catch {
            // Only the type: the error could carry the region.
            MXLog.error("Map snapshot failed: \(type(of: error))")
            return nil
        }
    }

    private func cachedImage(for key: MapSnapshotKey) -> UIImage? {
        guard let image = cache[key] else { return nil }
        markRecentlyUsed(key)
        return image
    }

    private func store(_ image: UIImage, for key: MapSnapshotKey) {
        cache[key] = image
        markRecentlyUsed(key)
        if cacheOrder.count > cacheLimit {
            cache[cacheOrder.removeFirst()] = nil
        }
    }

    /// Moves rather than appends, so each key appears once and eviction never drops a newer entry.
    private func markRecentlyUsed(_ key: MapSnapshotKey) {
        cacheOrder.removeAll { $0 == key }
        cacheOrder.append(key)
    }

    private func acquireRenderSlot() async {
        guard activeRenders >= maxConcurrentRenders else {
            activeRenders += 1
            return
        }
        await withCheckedContinuation { renderSlotWaiters.append($0) }
    }

    /// Hands the slot straight to the next waiter, so the count stays right.
    private func releaseRenderSlot() {
        if renderSlotWaiters.isEmpty {
            activeRenders -= 1
        } else {
            renderSlotWaiters.removeFirst().resume()
        }
    }

    /// `UIGraphicsImageRenderer` isn't available on watchOS, hence the image context.
    private static func drawPin(on map: UIImage, at point: CGPoint) -> UIImage {
        guard let pin = UIImage(systemName: "mappin.circle.fill")?.withTintColor(.red, renderingMode: .alwaysOriginal) else { return map }

        UIGraphicsBeginImageContextWithOptions(map.size, true, map.scale)
        defer { UIGraphicsEndImageContext() }

        map.draw(at: .zero)
        let pinRect = CGRect(x: point.x - pinSize / 2, y: point.y - pinSize / 2, width: pinSize, height: pinSize)
        // The symbol's pin is a cut-out, so a white disc keeps it readable on any map.
        UIColor.white.setFill()
        UIBezierPath(ovalIn: pinRect.insetBy(dx: 2, dy: 2)).fill()
        pin.draw(in: pinRect)

        return UIGraphicsGetImageFromCurrentImageContext() ?? map
    }
}

extension EnvironmentValues {
    /// `nil` shows the placeholder, e.g. in previews.
    @Entry var mapSnapshotLoader: MapSnapshotLoaderProtocol?
}
