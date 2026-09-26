# Element X watchOS: location sharing and the (+) button, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** From the chat composer's new (+) button, send your current location or share it live for 15 minutes or 1 hour. Show received locations and live shares as tappable map previews that open a full-screen map.

**Architecture:**
- **Proxies:**
  - A `RoomLocationProxy` wraps the SDK `Room` for starting, updating, stopping and observing live shares.
  - `TimelineProxy.sendLocation` sends one-off locations.
- **Services:**
  - A per-session `LiveLocationService` owns the single active share. It drives a `LocationProvider` (Core Location, with background updates only while sharing) on an injectable clock.
- **UI:**
  - `MKMapSnapshotter` draws the previews in chats.
  - A SwiftUI `Map` is the full-screen view.
  - The screens are MVVM-C like the rest of the app.

**Tech Stack:** Swift 6.2, SwiftUI, watchOS 11+ (Liquid Glass on 26), MapKit, CoreLocation, `MatrixRustSDK` (local package built from the `watchos-http-transport` fork branch), Swift Testing, Sourcery, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-09-26-watchos-location-sharing-design.md`. Read it first.

## Global Constraints

- **Repo and branch:** `~/Developer/git/github.com/element-hq/element-x-watchos`, `main` at `a07815a` plus this plan's commit. Create the branch `location-sharing` from it and don't push. The SDK fork is read-only here. element-x-ios is a read-only reference.
- **Architecture:** MVVM-C for every screen:
  - `…ScreenModels.swift`, `…ScreenViewModelProtocol.swift`, `…ScreenViewModel.swift` (`StateStoreViewModelV2`), `…ScreenCoordinator.swift`, `View/…Screen.swift`;
  - a `PreviewProvider` covering every main state.
- **Strings:** all go in `WatchStrings` (a `nonisolated enum`).
- **Styling:**
  - buttons use `.fullWidth` / `.fullWidthProminent` (Liquid Glass on watchOS 26), from `ElementXWatch/Sources/Other/SwiftUI/FullWidthButtonStyle.swift`;
  - colours use `Color.compound.*`.
- **Actor isolation:** app target `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Never add `@unchecked Sendable` / `nonisolated(unsafe)` by hand. SDK callbacks arrive on background threads; forward them with `SDKListener<T>.onMainActor`.
- **Privacy:** never log coordinates, `geo:` URIs or location descriptions. Log only events and counts, for example "Live location update sent (#12)".
- **Licence headers:** new watch-authored files use the single-line header from `ElementXWatch/Sources/Other/SwiftUI/FullWidthButtonStyle.swift`.
- **Member order:** properties → init → functions. For views: properties → init → `body` → other views → functions.
- **Sourcery mocks** drop the `Protocol` suffix (`RoomLocationProxyProtocol` → `RoomLocationProxyMock`). They regenerate on build into `ElementXWatch/Sources/Mocks/Generated/GeneratedMocks.swift`; commit that file.
- **Test helpers:** `waitUntil` and `AsyncGate` in `UnitTests/Sources/Support/TestHelpers.swift`; `Setup` in `TestFixtures.swift`.
- **Tests run on a FRESH throwaway simulator only.** The user's "Apple Watch Series 11 (46mm)" and "EXW Tests 26.5" simulators hold their real session, and the physical watch is off limits. Boot and wait before testing:
  ```bash
  cd ~/Developer/git/github.com/element-hq/element-x-watchos
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer PATH=/opt/homebrew/bin:$PATH
  RT=$(xcrun simctl list runtimes | grep -o "com.apple.CoreSimulator.SimRuntime.watchOS-26-5"); DT=$(xcrun simctl list devicetypes | grep -o "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-11-46mm" | head -1)
  T=$(xcrun simctl create "EXW Throwaway" "$DT" "$RT"); xcrun simctl bootstatus $T -b; sleep 5
  xcodegen -q && xcodebuild test -project ElementXWatch.xcodeproj -scheme ElementXWatch -destination "platform=watchOS Simulator,id=$T" -parallel-testing-enabled NO 2>&1 | tail -30
  xcrun simctl shutdown $T; xcrun simctl delete $T
  ```
  Output must be pristine: no `warning:` lines from `ElementXWatch/Sources` or `UnitTests/Sources`, no disabled tests.
- **Screenshots of unreachable screens:** add a temporary launch hook in the app, take a screenshot with `xcrun simctl io $T screenshot`, then revert the hook. Never commit it. Set a simulated location with `xcrun simctl location $T set 51.5072,-0.1276`.
- **Commits:** a title and a description, ending with:
  ```
  Co-Authored-By: <the model that wrote the commit> <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_014uxNdPz4FWU1X55AScSAaX
  ```

## Review Focus

1. **Live share started in room A, then in room B.**
   - Expected: after the confirmation, A is stopped (`stopLiveLocationShare` on A) before B starts.
   - Never both active at once, and the pill only in B.
   - Pinned in Task 4 (`startingInAnotherRoomStopsTheFirst`).
2. **The share is stopped from another device, such as the iPhone.**
   - Expected: the own-beacon update `live: false` stops Core Location and clears the pill within one update.
   - Pinned in Task 4 (`stopFromAnotherDeviceEndsTheShare`).
3. **The app relaunches mid-share.**
   - Expected: the own-beacon subscription reports the share is live with time left, so the service resumes sending, with the end time taken from the beacon.
   - A share that has already expired is not resumed.
   - Pinned in Task 4 (`resumesAnActiveShareAfterRelaunch`).
4. **Location permission is denied.**
   - Expected: the sheet shows the Settings explanation, all three buttons are disabled, and nothing is sent.
   - Pinned in Task 6 (`deniedPermissionDisablesSharing`).
5. **Invalid or foreign `geo:` URIs** (for example `geo:91,0`, `geo:abc`, `geo:51.5,-0.12,30;crs=wgs84;u=35`).
   - Expected: invalid ones map to a placeholder bubble with no crash, and valid variants parse.
   - Pinned in Task 1 (`GeoURITests`).

---

### Task 1: `GeoURI` and location items in the timeline

**Files:**
- Create: `ElementXWatch/Sources/Services/Location/GeoURI.swift`
- Modify: `ElementXWatch/Sources/Services/Timeline/TimelineItem.swift`, `TimelineItemFactory.swift`, `ElementXWatch/Sources/Other/WatchStrings.swift`, `ElementXWatch/Sources/Screens/ChatScreen/View/MessageBubble.swift` (temporary text rendering until Task 5)
- Test: `UnitTests/Sources/GeoURITests.swift`, `UnitTests/Sources/TimelineItemFactoryLocationTests.swift`

**Interfaces produced:**
```swift
struct GeoURI: Equatable { let latitude: Double; let longitude: Double; let uncertainty: Double?
    init?(string: String); var string: String }                     // "geo:51.5072,-0.1276;u=35"
struct LocationBody: Equatable { let geoURI: GeoURI?; let description: String?; let body: String }
struct LiveLocationBody: Equatable { let isLive: Bool; let lastGeoURI: GeoURI?; let lastUpdate: Date?; let senderID: String }
// TimelineItemBody gains: case location(LocationBody), case liveLocation(LiveLocationBody)
```

- [ ] **Step 1: Write the failing tests**

`UnitTests/Sources/GeoURITests.swift`:
```swift
@testable import ElementXWatch
import Testing

struct GeoURITests {
    @Test
    func parsesLatitudeLongitude() throws {
        let uri = try #require(GeoURI(string: "geo:51.5072,-0.1276"))
        #expect(uri.latitude == 51.5072)
        #expect(uri.longitude == -0.1276)
        #expect(uri.uncertainty == nil)
    }

    @Test
    func parsesAltitudeAndParameters() throws {
        let uri = try #require(GeoURI(string: "geo:51.5,-0.12,30;crs=wgs84;u=35"))
        #expect(uri.latitude == 51.5)
        #expect(uri.longitude == -0.12)
        #expect(uri.uncertainty == 35)
    }

    @Test
    func rejectsInvalidInput() {
        #expect(GeoURI(string: "geo:91,0") == nil)
        #expect(GeoURI(string: "geo:0,181") == nil)
        #expect(GeoURI(string: "geo:abc") == nil)
        #expect(GeoURI(string: "https://example.org") == nil)
        #expect(GeoURI(string: "geo:") == nil)
    }

    @Test
    func buildsAString() {
        #expect(GeoURI(latitude: 51.5072, longitude: -0.1276, uncertainty: 35).string == "geo:51.5072,-0.1276;u=35")
        #expect(GeoURI(latitude: 1, longitude: 2, uncertainty: nil).string == "geo:1.0,2.0")
    }
}
```

`UnitTests/Sources/TimelineItemFactoryLocationTests.swift` tests the pure mapping helpers the factory uses. Construct SDK records directly: `LocationContent` is a uniffi record with a public memberwise init.
```swift
@testable import ElementXWatch
import MatrixRustSDK
import Testing

struct TimelineItemFactoryLocationTests {
    @Test
    func mapsALocationMessage() {
        let content = LocationContent(body: "Location", geoUri: "geo:51.5,-0.12;u=10", description: "Home", zoomLevel: nil, asset: .sender)
        let body = TimelineItemFactory.locationBody(from: content)
        #expect(body == LocationBody(geoURI: GeoURI(latitude: 51.5, longitude: -0.12, uncertainty: 10), description: "Home", body: "Location"))
    }

    @Test
    func keepsAnInvalidLocationAsAPlaceholder() {
        let content = LocationContent(body: "Location", geoUri: "geo:abc", description: nil, zoomLevel: nil, asset: .sender)
        #expect(TimelineItemFactory.locationBody(from: content).geoURI == nil)
    }
}
```
Adapt the `LocationContent` / `AssetType` initializer labels to the generated bindings in `Packages/MatrixRustSDK/Sources/MatrixRustSDK/matrix_sdk_ffi.swift`. Add a test for `liveLocationBody(from:senderID:)` in the same style, built from the SDK's `LiveLocationContent` (`isLive`, plus its latest location if it has one).

- [ ] **Step 2: Run the tests to verify they fail.** Standard command; the build fails with "cannot find 'GeoURI' in scope".

- [ ] **Step 3: Implement**

`GeoURI.swift` (RFC 5870 subset). Split off `geo:`, then split on `;`:
- the first part is `lat,lon[,alt]`;
- a `u=` parameter is the uncertainty in metres;
- reject latitudes outside −90…90 and longitudes outside −180…180;
- `string` prints Swift's default `Double` description, plus `;u=<Int>` when there is an uncertainty.

`TimelineItem.swift`: add the two `TimelineItemBody` cases and the two structs.

`TimelineItemFactory`:
- `case .message` with a `.location(let content)` message type becomes `.location(locationBody(from:))`.
- The existing `case .poll, .liveLocation` splits: `.liveLocation(let content)` becomes `.liveLocation(liveLocationBody(from:senderID:))`, and `.poll` stays unsupported.
- Add `static func locationBody(from:)` and `static func liveLocationBody(from:senderID:)`.

`WatchStrings`: `location = "Location"`, `liveLocation = "Live location"`, `liveLocationEnded = "Live location ended"`.

`MessageBubble` content: until Task 5, render `.location` as `Label(WatchStrings.location, systemImage: "mappin.and.ellipse")` and `.liveLocation` as `Label(WatchStrings.liveLocation, systemImage: "location.fill")`.

`RoomSummaryPreview` (the chat list preview text): show "📍 Location" and "📍 Live location" for these kinds if it doesn't already.

- [ ] **Step 4: Run the tests to verify they pass** (full suite, pristine).
- [ ] **Step 5: Commit:** "Show location messages in the timeline", with a description and trailers.

---

### Task 2: room and timeline location APIs

**Files:**
- Create: `ElementXWatch/Sources/Services/Location/RoomLocationProxy.swift` (protocol and implementation), `ElementXWatch/Sources/Services/Location/LiveLocationSummary.swift`
- Modify: `TimelineProxy.swift` (adds `sendLocation`), `ClientProxyProtocol.swift` and `ClientProxy.swift` (add `roomLocationProxy(for:)` and `ownBeaconInfoPublisher`), `ClientProxyMock+Preview.swift` if needed
- Test: `UnitTests/Sources/LiveLocationSummaryTests.swift`

**Interfaces produced:**
```swift
enum LocationProxyError: Error, Equatable { case sdkError(String) }

struct LiveLocationSummary: Equatable, Identifiable {
    let userID: String; let startDate: Date; let lastGeoURI: GeoURI?; let lastUpdate: Date?
    var id: String { userID }
}
/// Applies one SDK diff batch to the summaries (VectorDiff semantics). Pure; unit tested.
enum LiveLocationSummaries { static func apply(_ updates: [LiveLocationShareUpdate], to summaries: [LiveLocationSummary]) -> [LiveLocationSummary]
                             static func summary(from share: LiveLocationShare) -> LiveLocationSummary }

// sourcery: AutoMockable
protocol RoomLocationProxyProtocol: AnyObject, Sendable {
    var roomID: String { get }
    /// Other people's (and our own) active live shares in this room.
    var liveLocationsPublisher: AnyPublisher<[LiveLocationSummary], Never> { get }
    func startLiveLocationShare(duration: Duration) async -> Result<String, LocationProxyError>   // beacon_info event ID
    func sendLiveLocation(_ geoURI: GeoURI) async -> Result<Void, LocationProxyError>
    func stopLiveLocationShare() async -> Result<Void, LocationProxyError>
}

// TimelineProxyProtocol gains:
func sendLocation(_ geoURI: GeoURI, description: String?) async -> Result<Void, TimelineProxyError>

// ClientProxyProtocol gains:
func roomLocationProxy(for roomID: String) async -> RoomLocationProxyProtocol?
/// Our own live shares across rooms, from `Client.subscribeToOwnBeaconInfoUpdates`.
var ownBeaconInfoPublisher: AnyPublisher<OwnBeaconInfo, Never> { get }
struct OwnBeaconInfo: Equatable { let roomID: String; let eventID: String; let isLive: Bool }
```

- [ ] **Step 1: Write the failing tests.** In `LiveLocationSummaryTests`, build `LiveLocationShare` values with their memberwise init, including a `lastLocation` of `LastLocation(location: LocationContent(...), ts: …)`. Test:
  - `summary(from:)` maps user ID, start and last location, with dates in milliseconds;
  - `apply` handles `append`, `pushBack`, `set`, `remove`, `clear` and `reset`, using the same index semantics as `ListDiff` in `ElementXWatch/Sources/Other/ListDiff.swift`, whose `apply` can be reused if it fits.

  Example:
  ```swift
  @Test
  func appliesDiffs() {
      let a = share("@a:x", lat: 1), b = share("@b:x", lat: 2)
      var summaries = LiveLocationSummaries.apply([.append(values: [a, b])], to: [])
      #expect(summaries.map(\.userID) == ["@a:x", "@b:x"])
      summaries = LiveLocationSummaries.apply([.set(index: 1, value: share("@b:x", lat: 3)), .remove(index: 0)], to: summaries)
      #expect(summaries.map(\.userID) == ["@b:x"])
      #expect(summaries.first?.lastGeoURI?.latitude == 3)
  }
  ```
- [ ] **Step 2: Run the tests to verify they fail.**
- [ ] **Step 3: Implement**
  - **`RoomLocationProxy`:**
    - `init(room: Room)`;
    - `startLiveLocationShare` → `room.startLiveLocationShare(durationMillis:)`;
    - `sendLiveLocation` → `room.sendLiveLocation(geoUri:)`;
    - `stopLiveLocationShare` → `room.stopLiveLocationShare()`;
    - `liveLocationsPublisher`: a `CurrentValueSubject` fed by `await room.liveLocationsObserver()` → `.subscribe(listener: SDKListener<[LiveLocationShareUpdate]>.onMainActor { … apply … })`. Keep both the observer and the `TaskHandle` stored, because the observer must stay alive. Subscribe lazily on the first access, or in an `async` `start()`.
    - Log errors as types or messages only.
  - **`TimelineProxy.sendLocation`:** `timeline.sendLocation(body: "Location", geoUri: geoURI.string, description: description, zoomLevel: nil, assetType: .sender, repliedToEventId: nil)`.
  - **`ClientProxy.roomLocationProxy(for:)`:** use the same `roomListService.room(roomId:)` path as `timelineProxy(for:)`.
  - **`ClientProxy.ownBeaconInfoPublisher`:** subscribe once in `ClientProxy.make` or lazily, and store the `TaskHandle`. `BeaconInfoUpdate` has `roomId`, `eventId` and `live`.
  - **Mocks:** regenerate them.
- [ ] **Step 4: Run the tests to verify they pass** (full suite).
- [ ] **Step 5: Commit:** "Add room and timeline location APIs".

---

### Task 3: `LocationProvider` and permissions

**Files:**
- Create: `ElementXWatch/Sources/Services/Location/LocationProvider.swift`
- Modify: `project.yml` (Info.plist properties), `ElementXWatch/SupportingFiles/Info.plist` (regenerated by XcodeGen)
- Test: `UnitTests/Sources/LocationProviderTests.swift` (authorization mapping only)

**Interfaces produced:**
```swift
enum LocationAuthorization: Equatable { case notDetermined, denied, authorized }
enum LocationError: Error, Equatable { case denied, timedOut, failed }

// sourcery: AutoMockable
protocol LocationProviderProtocol: AnyObject {
    var authorization: LocationAuthorization { get }
    var authorizationPublisher: AnyPublisher<LocationAuthorization, Never> { get }
    func requestAuthorization()
    /// One fix within `timeout`; `.denied` without asking if permission was refused.
    func currentLocation(timeout: Duration) async -> Result<GeoURI, LocationError>
    /// Continuous background updates for a live share (distance filter 10 m, nearest-ten-metres accuracy).
    var updatesPublisher: AnyPublisher<GeoURI, Never> { get }
    func startUpdates()
    func stopUpdates()
}
extension LocationAuthorization { init(_ status: CLAuthorizationStatus) }   // pure, tested
```

- [ ] **Step 1: Confirm the Info.plist keys watchOS needs for background location, and record the finding in the commit message.**
  - Check `NSLocationWhenInUseUsageDescription`.
  - Check the background mode entry: for watchOS apps this is `WKBackgroundModes` containing `location`, or `UIBackgroundModes`. Check the watchOS SDK documentation or headers, and look for `WKBackgroundModes` in the SDK.
  - Check whether `NSLocationAlwaysAndWhenInUseUsageDescription` is needed for `allowsBackgroundLocationUpdates` with when-in-use permission.
  - Add them under `targets.ElementXWatch.info.properties` in `project.yml`, with the copy "Share your location in chats."
- [ ] **Step 2: Write the failing test**, `authorizationMapsStatuses`, which checks:
  - `.notDetermined` → `.notDetermined`;
  - `.denied` and `.restricted` → `.denied`;
  - `.authorizedWhenInUse` and `.authorizedAlways` → `.authorized`.
- [ ] **Step 3: Implement `LocationProvider`.**
  - It's a `CLLocationManagerDelegate`. Delegate callbacks come in on the main thread for a manager created on the main thread; keep the class `@MainActor`, and add a `nonisolated` delegate forwarder if the compiler needs one.
  - **`currentLocation`:** `requestLocation()`, raced against the timeout with a `withTaskGroup` / continuation. Return the first fix as a `GeoURI` with `uncertainty = horizontalAccuracy`.
  - **`startUpdates`:** sets `allowsBackgroundLocationUpdates = true` and calls `startUpdatingLocation()`.
  - **`stopUpdates`:** stops updating and turns `allowsBackgroundLocationUpdates` off again.
  - Never log coordinates.
- [ ] **Step 4: Run the tests to verify they pass.** Also check that `plutil -p` on the built app's Info.plist shows the new keys.
- [ ] **Step 5: Commit:** "Add a location provider and location permissions".

---

### Task 4: `LiveLocationService`

**Files:**
- Create: `ElementXWatch/Sources/Services/Location/LiveLocationService.swift`
- Test: `UnitTests/Sources/LiveLocationServiceTests.swift`

**Interfaces produced:**
```swift
enum LiveLocationState: Equatable { case idle; case sharing(roomID: String, endsAt: Date, isPaused: Bool) }
enum LiveLocationServiceError: Error, Equatable { case startFailed, noLocationAccess }

// sourcery: AutoMockable
protocol LiveLocationServiceProtocol: AnyObject {
    var state: LiveLocationState { get }
    var statePublisher: AnyPublisher<LiveLocationState, Never> { get }
    /// Stops any share in another room first (callers confirm with the user before calling).
    func start(roomID: String, duration: Duration) async -> Result<Void, LiveLocationServiceError>
    func stop() async
}

final class LiveLocationService: LiveLocationServiceProtocol {
    init(locationProvider: LocationProviderProtocol,
         roomProvider: @escaping (String) async -> RoomLocationProxyProtocol?,
         ownBeaconInfoPublisher: AnyPublisher<OwnBeaconInfo, Never>,
         clock: any Clock<Duration> = ContinuousClock(),
         now: @escaping () -> Date = Date.init)
}
```

**Behaviour:** see spec §6. The constants live in the service: `minimumDistance = 20` m, `minimumInterval = .seconds(30)`, `keepAliveInterval = .seconds(180)` and `maxFailuresBeforePause = 3`.
- An update is sent when the new fix is ≥ 20 m from the last one sent and ≥ 30 s have passed since the last send.
- The keep-alive sends the last known fix every 3 min.
- At `endsAt`, or on `stop()`: stop updates, call `stopLiveLocationShare` (retry once on failure), then go to `.idle`.
- An own-beacon update with `isLive == false` for the active event ID behaves like `stop()`, without calling the SDK stop again.
- **On init, for a relaunch:** the first own-beacon update with `isLive == true` resumes sharing in that room. The service needs the end time: either extend `OwnBeaconInfo` in Task 2 with the start timestamp and timeout from the SDK (`BeaconInfo`), or query the room's live shares for our user. Pick whichever the SDK exposes, and write the choice in the report. Don't resume if the share has already expired.
- **Send failures:** count consecutive failures. At 3, set `isPaused: true`; on the next success, set `isPaused: false`.

- [ ] **Step 1: Write the failing tests.** Use `LocationProviderMock` with a `PassthroughSubject<GeoURI, Never>` for updates, `RoomLocationProxyMock` rooms, a test clock, and a controllable `now`. The test clock can be a small manual clock in `UnitTests/Sources/Support/TestClock.swift` if the project has none; check with `grep -rn "Clock" UnitTests/Sources/Support`.
  - `startingSendsAnInitialUpdateAndPublishesSharing`
  - `movingLessThan20MetresDoesNotSend`
  - `sendsAtMostEvery30Seconds`
  - `sendsAKeepAliveEvery3MinutesWhenStill`
  - `stopsAutomaticallyAtExpiry`: advance the clock past `endsAt`, then expect `stopLiveLocationShareCallsCount == 1`, `stopUpdates` called, and `.idle`.
  - `stopEndsTheShare`
  - `startingInAnotherRoomStopsTheFirst`: Review Focus #1.
  - `stopFromAnotherDeviceEndsTheShare`: Review Focus #2.
  - `resumesAnActiveShareAfterRelaunch`: Review Focus #3, plus an expired-share variant that doesn't resume.
  - `threeFailuresPauseThenASuccessResumes`
  - `startFailureLeavesTheServiceIdle`
- [ ] **Step 2: Run the tests to verify they fail.**
- [ ] **Step 3: Implement.** The sending loop is a single `Task` that uses the injected clock for timing, and is cancelled on stop. Never log coordinates.
- [ ] **Step 4: Run the tests to verify they pass.** Run `LiveLocationServiceTests` 3 times to check for flakiness, then the full suite.
- [ ] **Step 5: Commit:** "Add the live location service".

---

### Task 5: map previews, location bubbles and the full-screen map

**Files:**
- Create: `ElementXWatch/Sources/Services/Location/MapSnapshotLoader.swift`, `ElementXWatch/Sources/Screens/ChatScreen/View/LocationBubble.swift`, and `ElementXWatch/Sources/Screens/LocationMapScreen/{LocationMapScreenModels,LocationMapScreenViewModelProtocol,LocationMapScreenViewModel,LocationMapScreenCoordinator}.swift` plus `View/LocationMapScreen.swift`
- Modify: `MessageBubble.swift`, which replaces Task 1's labels with `LocationBubble`; `ChatScreen.swift`, `ChatScreenModels.swift` and `ChatScreenViewModel.swift`, to present the map
- Test: `UnitTests/Sources/LocationMapScreenViewModelTests.swift`, `UnitTests/Sources/MapSnapshotLoaderTests.swift` (cache-key logic only)

**Interfaces produced:**
```swift
// sourcery: AutoMockable
protocol MapSnapshotLoaderProtocol: AnyObject {
    func snapshot(of geoURI: GeoURI, size: CGSize) async -> UIImage?
}
/// Cache key rounds to 4 decimal places (~11 m) and the size, so live updates that barely move reuse the image. Pure, tested.
struct MapSnapshotKey: Hashable { init(geoURI: GeoURI, size: CGSize) }

enum LocationMapScreenMode: Equatable { case location(GeoURI, description: String?); case live(userID: String) }
struct LocationMapScreenViewState: BindableState { var geoURI: GeoURI?; var title: String; var isLive: Bool; var hasEnded: Bool }
enum LocationMapScreenViewAction { case openInMaps }
// LocationMapScreenViewModel(mode:, liveLocationsPublisher: AnyPublisher<[LiveLocationSummary], Never>?, openInMaps: (GeoURI, String?) -> Void)
// ChatScreenViewAction gains: case showLocation(EventItem)
```

- **Snapshots:**
  - `MapSnapshotLoader` uses `MKMapSnapshotter` with a region of about 500 m around the point, the requested size and `traitCollection`/scale 2. It draws a red pin (`mappin.circle.fill` SF Symbol) at the centre point.
  - Images are cached in memory with `NSCache` or a dictionary capped at about 30 entries.
  - It's injected like `MediaLoader`, as an environment value (`\.mapSnapshotLoader`) built in `UserSessionFlowCoordinator`.
- **`LocationBubble`:**
  - The snapshot is about 136 × 90 pt with 8 pt rounded corners. The description, if any, goes below it in `.footnote`.
  - Live shares show "Live · updated 30 s ago" (a relative time from `lastUpdate`) or "Live location ended".
  - The snapshot only reloads when the `MapSnapshotKey` changes (`.task(id:)`), which gives the spec's "redraw only after noticeable movement". The 4-decimal rounding is about 11 m; spec §4 says more than 25 m, so round to 3.5 decimals equivalently, or compare the distance to the last drawn point with `CLLocation.distance(from:)`. Implement the 25 m rule, and test it in `MapSnapshotLoaderTests` as a pure `shouldRedraw(from:to:)` helper.
  - **Placeholder:** if the `GeoURI` is nil or the snapshot fails, show a grey `bgSubtleSecondary` rectangle with 📍. For a valid `GeoURI`, add the coordinates to 3 decimals as text. That's only on screen, never logged.
  - Tap to open the map. Own live shares show **Stop** here, calling `ChatScreenViewAction.stopLiveLocation`, which is added in Task 7. Leave a hook: in Task 5, Stop isn't shown yet.
- **`LocationMapScreen`:**
  - A SwiftUI `Map(initialPosition:)` with a `Marker`.
  - Crown zoom is the Map's built-in behaviour on watchOS, so check it works; if it doesn't, use `.digitalCrownRotation` on the camera distance.
  - A glass **Open in Maps** button calls `MKMapItem(location: …, address: nil)` / `MKMapItem(placemark:)` `.openInMaps()`, using the API the watchOS SDK offers.
  - Live mode follows the updates from `liveLocationsPublisher`, filtered to `userID`, and shows "Live location ended" when that user's share leaves the list or `isLive` goes false.
  - It's presented as `.fullScreenCover` from `ChatScreen`.
- **Chat screen:** `ChatScreenViewModel` needs the room's `RoomLocationProxy` to supply `liveLocationsPublisher`, both for the live bubbles' latest positions and for the map. Pass `RoomLocationProxyProtocol?` into `ChatScreenCoordinator` / `ChatScreenViewModel` from `ChatLoaderCoordinator`, which gets it via `clientProxy.roomLocationProxy(for:)` next to the timeline. A live bubble's latest position comes from the summaries, matched by sender ID, falling back to the event's own last location.

- [ ] **Step 1: Write the failing tests.**
  - The `MapSnapshotKey` rounding and the `shouldRedraw` 25 m threshold.
  - `LocationMapScreenViewModel`:
    - a one-off location sets `geoURI`;
    - live mode follows publisher updates for that user;
    - it's marked ended when the user disappears;
    - `.openInMaps` calls the closure with the current coordinate.
  - A `ChatScreenViewModel` test showing `.showLocation` sets the binding.
- [ ] **Step 2: Run the tests to verify they fail.**
- [ ] **Step 3: Implement.** Add previews: `LocationBubble` in one-off, one-off without a snapshot, live, live ended and own-live states, and `LocationMapScreen` one-off and live.
- [ ] **Step 4: Run the tests to verify they pass.** Take screenshots of the map screen and a chat with location bubbles through a temporary launch hook, with a simulated location. Save them as `scratchpad/location-bubbles.png` and `scratchpad/location-map.png` (scratchpad path: `/private/tmp/claude-501/-Users-calini-Developer-git-github-com-element-hq-element-x-ios/25dc6f09-27c4-464d-9da6-1aa543703643/scratchpad/`).
- [ ] **Step 5: Commit:** "Show locations as map previews with a full-screen map".

---

### Task 6: the (+) button, Attachments and the Location sheet

**Files:**
- Create: `ElementXWatch/Sources/Screens/AttachmentsScreen/…` (MVVM-C set plus `View/AttachmentsScreen.swift`) and `ElementXWatch/Sources/Screens/LocationSharingScreen/…` (MVVM-C set plus `View/LocationSharingScreen.swift`)
- Modify: `ChatScreen.swift` (composer), `ChatScreenModels.swift`, `ChatScreenViewModel.swift`, `ChatScreenCoordinator.swift`, and the `ChatLoaderCoordinator` in `UserSessionFlowCoordinator.swift`. Create one `LocationProvider` and one `LiveLocationService` per session in `UserSessionFlowCoordinator`, using `clientProxy.roomLocationProxy(for:)` as the room provider and `clientProxy.ownBeaconInfoPublisher`, and pass them into chats.
- Test: `UnitTests/Sources/AttachmentsScreenViewModelTests.swift`, `UnitTests/Sources/LocationSharingScreenViewModelTests.swift`

**Interfaces produced:**
```swift
enum AttachmentsScreenViewModelAction { case location }
// LocationSharingScreenViewModel(roomID:, roomName:, locationProvider:, liveLocationService:, sendLocation: (GeoURI) async -> Result<Void, TimelineProxyError>, snapshotLoader:)
struct LocationSharingScreenViewState: BindableState {
    var authorization: LocationAuthorization; var geoURI: GeoURI?; var isLocating: Bool; var locateFailed: Bool
    var isBusy: Bool; var otherShareRoomName: String?; var bindings: LocationSharingScreenBindings }
struct LocationSharingScreenBindings { var confirmReplace: LiveShareDuration?; var errorMessage: String? }
enum LiveShareDuration: CaseIterable { case fifteenMinutes, oneHour; var duration: Duration }
enum LocationSharingScreenViewAction { case appear, tryAgain, sendCurrent, shareLive(LiveShareDuration), confirmReplace, cancelReplace }
enum LocationSharingScreenViewModelAction { case done }
```

**Flow** (spec §4):
- **Composer:** an `HStack` with the round glass (+) button (`.glassEffect(.regular.interactive(), in: .circle)` on watchOS 26, falling back to a capsule background) and the Reply `TextFieldLink` with `.fullWidth`.
- **(+):** opens `AttachmentsScreen` as a sheet in a `NavigationStack`. It has one `ListRow`-like button, "📍 Location", which pushes `LocationSharingScreen`.
- **On appear, `LocationSharingScreen`:**
  - requests authorization if it hasn't been asked yet;
  - fetches `currentLocation(timeout: .seconds(30))`;
  - shows the snapshot, or "Finding your location…", or "Couldn't get your location." with Try again;
  - if permission is denied, shows `WatchStrings.locationAccessOff` and disables all buttons (Review Focus #4).
- **Buttons:**
  - **Send current location** calls `sendLocation(geoURI)`. On success it emits `.done`, which closes the sheet; on failure it shows the "Couldn't send location." alert.
  - **Share live · 15 min / · 1 hour:**
    - If `liveLocationService.state` is sharing in another room, it sets `confirmReplace`, and the alert "Stop sharing in <room> and share here instead?" offers Share here and Cancel. Get the room name from `RoomSummaryProvider`, or show "another chat" if it's unknown.
    - Otherwise it calls `start(roomID:duration:)`: `.done` on success, "Couldn't start live location." on failure.
- **Strings** (in `WatchStrings`): `locationTitle = "Location"`, `sendCurrentLocation = "Send current location"`, `shareLive15 = "Share live · 15 min"`, `shareLive60 = "Share live · 1 hour"`, `findingLocation = "Finding your location…"`, `locationFailed = "Couldn't get your location."`, `locationAccessOff = "Location access is off. Turn it on in Settings → Privacy & Security → Location Services."`, `sendLocationFailed = "Couldn't send location."`, `startLiveFailed = "Couldn't start live location."`, `replaceLiveShareTitle = "Stop sharing in %@ and share here instead?"` (use `String(format:)` or interpolation), `shareHere = "Share here"`, `attachmentsTitle = "Attach"`, `attachments = "Attachments"` (the (+) accessibility label).

- [ ] **Step 1: Write the failing tests.**
  - Attachments: `.location` is forwarded.
  - Location sharing:
    - `appearRequestsPermissionAndLocates`
    - `deniedPermissionDisablesSharing` (Review Focus #4)
    - `timeoutShowsTryAgain`
    - `sendCurrentSendsAndFinishes`
    - `sendFailureShowsError`
    - `shareLiveStartsAndFinishes`
    - `shareLiveWhileSharingElsewhereAsksFirst`
    - `confirmReplaceStartsHere`
    - `cancelReplaceDoesNothing`
- [ ] **Step 2: Run the tests to verify they fail.**
- [ ] **Step 3: Implement.** Include previews: locating, located, failed, denied, and the replace confirmation.
- [ ] **Step 4: Run the tests to verify they pass.** Take screenshots of the composer with (+), the Attachments sheet and the Location sheet with a simulated location. Save them as `scratchpad/composer-plus.png`, `scratchpad/attachments.png` and `scratchpad/location-sheet.png`.
- [ ] **Step 5: Commit:** "Add the (+) button and location sharing sheet".

---

### Task 7: live share pill, Stop, and TESTING.md

**Files:**
- Create: `ElementXWatch/Sources/Screens/ChatScreen/View/LiveLocationPill.swift`
- Modify: `ChatScreen.swift`, `ChatScreenModels.swift`, `ChatScreenViewModel.swift` (subscribes to `liveLocationService.statePublisher`), `LocationBubble.swift` (Stop for own live shares), `TESTING.md`
- Test: additions to `UnitTests/Sources/ChatScreenViewModelTests.swift` (or the chat VM test file that exists)

**Interfaces produced:**
```swift
// ChatScreenViewState gains: var liveShare: LiveShareBanner?   struct LiveShareBanner: Equatable { let endsAt: Date; let isPaused: Bool }
// ChatScreenViewAction gains: case stopLiveLocation
```

- **Pill:**
  - Shown at the top of the chat's `LazyVStack`, as a sticky overlay or `safeAreaInset(edge: .top)` that stays visible, only when `liveLocationService.state` is `.sharing` for this room.
  - The text is "📍 Sharing live · 12 min left", using `Text(timerInterval:)`, or a minute-granularity countdown via `TimelineView(.periodic(from:by: 60))`. When paused, it reads "Live location paused, retrying…".
  - A small glass **Stop** button calls `.stopLiveLocation` → `liveLocationService.stop()`.
- **Timeline Stop:** own live-location bubbles show **Stop** while this room's share is active.
- **TESTING.md:** add the manual rows from spec §8, and a line noting location permission and background location.

- [ ] **Step 1: Write the failing tests** for the chat VM:
  - `showsTheBannerWhileSharingHere`
  - `hidesTheBannerForAnotherRoom`
  - `pausedStateIsShown`
  - `stopCallsTheService`
- [ ] **Step 2: Run the tests to verify they fail.**
- [ ] **Step 3: Implement,** with previews for the pill (active and paused).
- [ ] **Step 4: Run the tests to verify they pass.** Take a screenshot of the chat with the pill through a temporary hook: `scratchpad/live-pill.png`.
- [ ] **Step 5: Commit:** "Show the live location pill with Stop".
