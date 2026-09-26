# Element X watchOS: location sharing and the (+) button

Date: 2026-09-26
Status: design approved in conversation, pending written-spec review
Builds on: v0.2.0 (`0ff5e6f`)

## 1. Why

The user wants to share where they are from the watch without the phone. They want to send their current location, share it live for a short time, and see locations other people send, all in DMs and groups. The composer gets a (+) button for attachments. Location is its first use; voice messages will be the second, in a separate project.

## 2. Findings that shape the design

- **The SDK already supports everything needed:**
  - `Timeline.sendLocation(body:geoUri:description:zoomLevel:assetType:repliedToEventId:)` sends a one-off location.
  - `Room.startLiveLocationShare(durationMillis:) -> String`, `Room.sendLiveLocation(geoUri:)` and `Room.stopLiveLocationShare()` handle a live share.
  - `Client.subscribeToOwnBeaconInfoUpdates(listener:)` reports the state of your own share.
  - `Room.liveLocationsObserver()` gives a `LiveLocationsObserver` that reports other people's shares: `LiveLocationShare { userId, startTs, lastLocation: LastLocation? … }` in batches.
  - Location messages arrive as `MsgLikeKind.message` with a location `MessageType` whose `LocationContent` holds `body`, `geoUri`, `description`, `zoomLevel` and `asset`.
  - No SDK changes are needed.
- **The watchOS frameworks cover it:**
  - `MKMapSnapshotter` (watchOS 1+) draws static map images.
  - SwiftUI `Map` provides the interactive map.
  - `CLLocationManager.allowsBackgroundLocationUpdates` (watchOS 4+), together with the `location` background mode, keeps updates coming with the wrist down.
- **Element X iOS offers the same features:** it sends static locations and live shares, but draws maps with MapLibre. The watch uses MapKit instead and adds no dependencies.
- **What the watch has today:** received location messages show as unsupported items.

## 3. Scope

In scope:
1. A (+) button in the chat composer that opens an Attachments sheet. Location is its only row for now.
2. The Location sheet:
   - a map preview of your current position;
   - **Send current location**;
   - **Share live · 15 min**;
   - **Share live · 1 hour**.
3. Live sharing:
   - a background location stream that sends updates at a set rate;
   - automatic stop when the time runs out;
   - a Stop control;
   - one active share at a time.
4. An in-chat pill for your active live share: "📍 Sharing live · 12 min left · Stop".
5. Received locations as timeline bubbles with a map snapshot:
   - one-off locations;
   - other people's live shares, showing when they last updated and whether they've ended.
6. A full-screen map for any location, with Crown zoom, drag to pan, and **Open in Maps**.

Out of scope, for later:
- dropping a pin on a map to share a different place;
- voice messages, which will join the Attachments sheet as its own project;
- an 8-hour live share;
- a list of active shares in Settings;
- sharing to more than one room at a time.

## 4. Screens and flows

**Composer**
- A small round Liquid Glass **(+)** button sits to the left of Reply, which becomes a slightly narrower glass capsule.
- (+) opens the **Attachments** sheet. It has a `NavigationStack`, the system glass ✕, and one row: 📍 **Location**.

**Location sheet**
- **Map preview:** a snapshot at the top, centred on your current position, with a pin.
  - While waiting for a position, it shows "Finding your location…" with a spinner.
  - After 30 s without one, it shows "Couldn't get your location." and a Try again button.
- **Buttons:** three full-width glass buttons.
  1. **Send current location** sends straight away, with no extra confirmation, and closes the sheet.
  2. **Share live · 15 min** starts a live share and closes the sheet.
  3. **Share live · 1 hour** does the same for an hour.
- **Permission:** the first time, the system asks for location permission ("when in use", plus background use during a live share). If you decline, the sheet says "Location access is off. Turn it on in Settings → Privacy & Security → Location Services." and the buttons are disabled.
- **Another share already running:** starting a live share while one is active in another room asks "Stop sharing in <room> and share here instead?", with Share here and Cancel.

**Your active live share**
- **Pill:** a glass pill pinned above the messages in that room reads "📍 Sharing live · 12 min left" with **Stop**. It counts down every minute and disappears when the share ends.
- **Timeline message:** your live share also appears in the timeline as a location bubble, with a Stop button while it's running.

**Location bubbles**
- **One-off location:** a map snapshot about 136 × 90 pt with a pin, the description if there is one, and the sender, as for other messages. Tap to open full screen.
- **Someone else's live share:**
  - a snapshot of their latest position with "Live · updated 30 s ago";
  - it redraws only when they've moved noticeably (more than 25 m), not on every update;
  - once it ends, it shows "Live location ended" and their last position.
- **Your own live share:** the same bubble, with Stop while it's running.

**Full-screen map**
- An interactive SwiftUI `Map` with the pin (or the person's latest position for a live share), zoomed with the Crown and panned by dragging.
- For a live share, the pin moves as updates arrive while the screen is open.
- A glass **Open in Maps** button opens the coordinate in Apple Maps (`MKMapItem.openInMaps`).
- The system ✕ closes it.

## 5. Components

**Services** (under `ElementXWatch/Sources/Services/Location/`):

| Unit | Responsibility |
|---|---|
| `LocationProviderProtocol` / `LocationProvider` | Wraps `CLLocationManager`: authorization status and requests, `currentLocation() async -> Result<CLLocation, LocationError>` with a 30 s timeout, and a background update stream (`startUpdates` / `stopUpdates`, `allowsBackgroundLocationUpdates = true` only while a live share runs). AutoMockable. |
| `LiveLocationServiceProtocol` / `LiveLocationService` | One per signed-in session. It owns the single active share: room, end time and sending loop. `start(roomID:duration:)`, `stop()`, and a `statePublisher` of `.idle` / `.sharing(roomID, endsAt, isPaused)`. It uses `JoinedRoomProxy` for start, send and stop, and the own-beacon subscription so the state stays right if the share is stopped from another device. It uses an injectable clock for tests. |
| `RoomLiveLocationsProxy` | Wraps `Room.liveLocationsObserver()` and publishes `[LiveLocationSummary]` (user ID, display name, last coordinate, last update time, active or ended) for a room. |
| `GeoURI` | Parses and builds `geo:<lat>,<lon>[;u=<accuracy>]`. Pure and unit tested. |
| `MapSnapshotLoader` | `MKMapSnapshotter` wrapped in an async function: image for a coordinate, size and span, with a pin drawn on top and an in-memory cache keyed by rounded coordinate and size. |

**Proxy additions:**
- `TimelineProxy.sendLocation(body:geoURI:description:) async -> Result<Void, TimelineProxyError>`.
- `JoinedRoomProxy` (or its watch equivalent) gets `startLiveLocationShare(duration:)`, `sendLiveLocation(geoURI:)`, `stopLiveLocationShare()` and `liveLocationsProxy()`, all returning results with typed errors.

**Timeline:**
- `TimelineItemBody.location(LocationBody)` (coordinate, description, uncertainty), mapped by `TimelineItemFactory` from location messages.
- Live shares show as `.liveLocation(LiveLocationBody)`, combining the start event with the latest `RoomLiveLocationsProxy` data for that sender.

**Screens** (MVVM-C, `StateStoreViewModelV2`, previews for every state):
- `AttachmentsScreen`: the (+) sheet.
- `LocationSharingScreen`: the snapshot and the three actions, plus the permission and error states.
- `LocationMapScreen`: the full-screen map.
- `ChatScreen` additions: the (+) button, `LocationBubble`, and `LiveLocationPill`.

**Configuration:**
- `NSLocationWhenInUseUsageDescription`: "Share your location in chats."
- Background location use for live sharing: the `location` background mode (`WKBackgroundModes`/`UIBackgroundModes`) and `NSLocationAlwaysAndWhenInUseUsageDescription` if watchOS requires it for background updates. The plan confirms the exact keys.

## 6. Live sharing behaviour

- **Sending rhythm:**
  - An update goes out when you've moved at least 20 m since the last one, at most once every 30 s.
  - A keep-alive update goes out every 3 minutes while you're still.
  - Updates use `kCLLocationAccuracyNearestTenMeters` and a `distanceFilter` of 10 m.
- **Ending:** at the end of the time, or on Stop, the watch stops Core Location, turns off background updates and calls `stopLiveLocationShare()`.
  - If the app is killed mid-share, the share still ends on its own when its time runs out.
  - When the app relaunches, the own-beacon subscription reports whether a share is still active in its time window. If it is, the service resumes sending.
- **Background:** updates keep flowing with the wrist down, through the background location mode.
- **Sync during a share (ruling R4, corrects an earlier assumption):** sync keeps running while a live share is active, even with the wrist down, and pauses again once it ends. The SDK sends each update and the stop against our `beacon_info` as last synced into its state store (sending the state event doesn't write it there), and stops made elsewhere reach the watch only through sync. So the first update waits until sync reports the new share as live (30 s at most), "not synced yet" failures before then don't count towards pausing, and a stop that fails for that reason is retried once the share syncs (30 s at most).
- **Privacy:**
  - Coordinates never go into logs, only events such as "live location update sent (#12)".
  - Background location is only active while a live share runs.

## 7. Errors

| Situation | What happens |
|---|---|
| Permission denied or restricted | The explanation text; buttons disabled |
| No position yet | "Finding your location…" |
| No position after 30 s | "Couldn't get your location." with Try again |
| Sending a location fails | Toast: "Couldn't send location." No automatic retry |
| Starting a live share fails | Toast: "Couldn't start live location." |
| A live update fails | Retried on the next tick. After 3 failures in a row the pill shows "Live location paused, retrying…", and the service keeps trying until the share ends |
| Stop fails | The share still ends locally, and stopping is retried once. If it still fails, the share expires on its own |
| Snapshot fails | Grey placeholder with a 📍 and the coordinates as text; tap still opens the full-screen map |

## 8. Testing

- **Unit tests** (Swift Testing, Sourcery mocks, injectable clock):
  - `GeoURI` parsing and building, including uncertainty and invalid input.
  - `LiveLocationService`:
    - the 20 m threshold and 30 s limit;
    - the 3-minute keep-alive;
    - automatic stop at expiry;
    - Stop;
    - a stop reported by the own-beacon subscription from another device;
    - one share at a time (starting in room B stops room A);
    - failure counting and the paused state;
    - resuming after relaunch.
  - The view models for the Attachments, LocationSharing and LocationMap screens, including permission, timeout and error states.
  - `TimelineItemFactory` mapping of location and live-location items.
  - `RoomLiveLocationsProxy` summary mapping.
- **Previews and screenshots:** previews for every screen and bubble state, and screenshots on a throwaway simulator using the simulator's simulated location.
- **Manual on the watch** (added to `TESTING.md`):
  - Send your current location and check it shows in Element X on the iPhone.
  - Share live for 15 min, walk around with your wrist down, and check the updates arrive on the iPhone.
  - Tap Stop and check the share ends everywhere.
  - Start a live share on the iPhone and check the watch shows it and follows it on the full-screen map.
  - Check battery use over a 1-hour share.

## 9. Follow-ups

- Dropping a pin on a map to share a different place: the map starts on your position and you move around.
- Voice messages in the Attachments sheet. This needs libopus and libogg built for watchOS, because Element X only plays `audio/ogg`.
- A list of active live shares in Settings.
- An 8-hour live share, if wanted.
