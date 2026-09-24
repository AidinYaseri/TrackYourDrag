<img src="Docs/icon-preview.png" width="96" align="right" alt="Tracky app icon">

# Tracky

**Measure Your Drive.**

A native iOS performance-tracking app for car enthusiasts. Tracky uses the
iPhone's GPS, accelerometer, gyroscope and barometer to measure acceleration
times, distance runs, G-force and elevation, and keeps a history you can sort,
chart, map and compare.

Swift 5, SwiftUI, SwiftData, Core Location, Core Motion, MapKit and Swift
Charts. iOS 17 and later.

---

## What it measures

| Acceleration | Distance | Live telemetry |
| --- | --- | --- |
| 0–60 mph | 1/8 mile (201 m) | Speed |
| 0–100 km/h | 1/4 mile (402 m) | Longitudinal, lateral and combined G |
| 0–100 mph | 1/2 mile | Max acceleration, braking and cornering G |
| 0–200 km/h | 1 km | Elevation and elevation change |
| 60–130 mph | Any custom distance | Distance travelled |
| Any custom speed interval | | GPS accuracy and quality |

Distance runs also record the usual drag-strip markers (60 ft, 330 ft, 1/8
mile, 1000 ft) and the trap speed at the finish line. Speed runs record
intermediate speed splits.

## Screens

- **Drive** — the dashboard. GPS status, one-tap mode and vehicle selection,
  a large speed readout, a live G strip and four telemetry tiles, and one big
  START RUN button. Arming puts the app in a waiting state; the launch and the
  finish are detected automatically, so nothing has to be touched while moving.
- **Runs** — every saved run, sortable by date, time, distance or vehicle and
  filterable by vehicle and mode. Tap for the full record: stats, splits,
  swipeable graphs, elevation, the route map and the GPS quality report. Any
  two runs can be compared, with their speed curves overlaid.
- **Stats** — personal bests per mode, G-force records, lifetime totals, and a
  trend chart that marks the runs which set a record at the time.
- **Settings** — units, sensor rate, one-foot rollout, vehicles, appearance,
  haptics, data export and the privacy controls.

## How the measurement works

The short version is in the app under Settings → How Tracky measures. The
longer version:

**Speed.** Core Location derives ground speed from Doppler shift rather than
from the gap between positions, which makes it far more precise than it looks.
Tracky runs it through a Kalman filter that also takes acceleration from the
accelerometer, so the estimate stays smooth between fixes without lagging
behind a car that is still pulling.

**Timing.** GPS arrives about ten times a second, so a car is almost never
sampled at exactly 100 km/h or exactly 402 m. Waiting for a matching sample
would add up to a tenth of a second of error, which is a lot when the answer is
under five seconds. Instead every threshold is resolved by interpolating
between the two samples that straddle it. A standing start is back-projected
from the first two moving samples to estimate the instant the car left the
line; a rolling start is the interpolated instant the trace crossed the start
speed.

**Distance.** Integrated from filtered speed, not summed between positions.
Consecutive fixes can wander several metres, and over a twelve second quarter
mile that noise would swamp the answer.

**G-force.** Core Motion separates gravity from vehicle acceleration and
solves the device attitude against true north. Rotating the acceleration by
that attitude gives it in world terms; projecting onto the GPS course splits it
into longitudinal and lateral in the *car's* frame, so the phone does not need
to be aligned with the car. Without a north-referenced attitude the
longitudinal value falls back to differentiated GPS speed and the lateral
value is marked as an estimate.

**Elevation.** GPS altitude is stable over time but coarse; a barometer
resolves centimetres of change but knows nothing about sea level and drifts
with the weather. Tracky low-passes GPS altitude for the reference and adds the
barometer's relative altitude on top, so short-term detail comes from the
barometer and long-term truth from GPS.

**What gets thrown away.** Fixes worse than the accuracy limit are discarded,
as are fixes implying an acceleration no car can produce — which is what a
receiver reports when it re-acquires satellites after a bridge. Discarded fixes
are counted and reported on the run.

**After the finish line.** Recording continues for a few seconds past the
finish so the chart shows the car slowing down and the braking and cornering
peaks are real numbers. The time, distance and speeds only ever come from
between the start and finish lines.

### On accuracy

A phone is not a timing beam. Results depend on GPS reception, the handset, the
mount, the road surface, satellite visibility and how securely the phone is
held. Tracky grades every run — Excellent, Good, Fair or Poor — from the
accuracy it actually received, lists anything odd that happened, and refuses to
count a poor run towards a personal best.

## Architecture

```
Tracky/
├── App/            App entry point, tab shell, UIKit chrome
├── Models/         Units, run modes, telemetry points, results, SwiftData models
├── Core/           The measurement core. No SwiftUI, no Core Location, no SwiftData.
├── Services/       Sensors, persistence, settings, export, orchestration
├── DesignSystem/   Palette, typography, metrics, motion, haptics
├── Components/     Reusable SwiftUI views
├── Features/       Drive, Runs, Stats, Settings, Vehicles, Map
└── Resources/      Asset catalog
```

The rule that shapes everything: **nothing in `Core/` imports a framework the
tests cannot run against.** The whole measurement path — filtering, outlier
rejection, interpolation, launch and finish detection, G resolution, run
validation and personal bests — is plain Swift over value types, so it can be
checked against physics instead of against itself.

| Type | Responsibility |
| --- | --- |
| `LocationManager` | Core Location, configured for vehicle use, emitting `LocationSample` |
| `MotionManager` | Device motion at a configurable rate, plus the barometer |
| `DriveSource` | One protocol over the real sensors and the simulator |
| `TelemetryProcessor` | Filtering, fusion and integration into one clean sample stream |
| `PerformanceEngine` | Arm, launch, splits, finish, abort, result assembly |
| `RunValidator` | Signal quality verdict and warnings |
| `RunManager` | Ties it together for the UI and throttles updates to 20 Hz |
| `RunStore` | SwiftData writes, sorting and the privacy controls |
| `ExportService` | Share card and CSV |

## Running it in the Simulator

The Simulator gives no motion data at all and only a fixed location, so Tracky
generates its own drive there. `SimulatedDriveSource` models a car —
acceleration falling off exponentially with speed, clipped by traction, with
believable GPS noise — and feeds it through the same processor and engine as
the real sensors. Arm a run and it launches by itself a few seconds later.

The same generator seeds the demo history on first launch, so Runs, Stats and
the maps all have something in them. Demo mode can also be switched on from
Settings on a real device.

## Building

Open `Tracky.xcodeproj` and run the `Tracky` scheme on an iOS 17 simulator or
device. There are no dependencies to fetch. The project uses Xcode 16
file-system synchronised groups, so new files in `Tracky/` and `TrackyTests/`
are picked up without editing the project.

`project.yml` is an optional [XcodeGen](https://github.com/yonaskolb/XcodeGen)
spec if you would rather regenerate the project from scratch.

## Tests

```
xcodebuild test -scheme Tracky -destination 'platform=iOS Simulator,name=iPhone 15'
```

The suite covers interpolation and threshold crossings, the engine against
constant-acceleration physics (0–100 km/h, quarter mile, trap speed, rolling
starts, rollout, splits, aborts), the G-force maths with hand-built vectors,
the filters and outlier rejection, distance integration, personal bests and
trends, unit conversion and formatting, and an end-to-end pass through the real
processor and engine.

## Branding

The mark is a 270-degree speedometer sweep open at the bottom with a "T" whose
stem leans right and runs out through that opening. It is drawn as SwiftUI
shapes (`TrackyMark`) and the app icon is rasterised from exactly the same
proportions by `Tools/generate_app_icon.py`, which uses only the Python
standard library:

```
python3 Tools/generate_app_icon.py
```

## Safety and privacy

Tracky is a telemetry and performance measurement tool. Always use it
responsibly and only perform performance testing where it is legal and safe to
do so.

Everything stays on the device. Nothing is uploaded and no account is needed.
Route recording can be turned off before a run, an individual run's coordinates
can be removed afterwards, and Settings can strip location data from every run
at once. Exports go through the system share sheet, so where a file goes is
always the user's decision, and a run whose location data was removed never
exports coordinates.
