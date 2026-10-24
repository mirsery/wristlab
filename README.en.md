<div align="center">

# Wristlab

Watch daily care is implemented in the working tree, with Gate 3 accepted for the code/simulator stage and disclosed platform gaps; device acceptance is still pending. It adds Care / Activity / State pages, icons with short labels instead of direct scores, opt-in read-only daily activity, and an optional same-day private mood record. Mood is not scored, synced, or placed in widgets. Local-only stress history is never fabricated from phone snapshots. See the [acceptance report and remaining checks](.stdd/archive/2026-10-23-watch-daily-care/test-report.md). Existing checked-in Watch screenshots predate this redesign; simulator builds do not prove real-device behavior.

<img src="docs/brand/icon-master.png" width="88" alt="Wristlab app icon" />

**A clearer view of your day.**

A local-first health trends lab for iPhone and Apple Watch.

[简体中文](README.md) · [Specifications](specs/README.md) · [Development](docs/development.md) · [Validation](docs/validation.md)

![CI](https://github.com/mirsery/wristlab/actions/workflows/ci.yml/badge.svg)
![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![Platforms](https://img.shields.io/badge/iOS-17%2B%20%7C%20watchOS%2010%2B-222)
![License](https://img.shields.io/badge/License-MIT-8DEDB6)

</div>

## Feature Dashboard

The iCloud data-center implementation optionally syncs only four interface preferences, never health records, weights, goals or plans. It requires CloudKit-capable signing; the current Personal Team cannot sign that capability. Real cloud writes, device installation and cross-device restoration remain unverified. See [configuration notes (Chinese)](docs/development.md#icloud界面偏好同步).

The default build disables CloudKit capabilities and runtime access while retaining its implementation. Future cloud builds explicitly use `project-icloud.yml` with a capable team. Local iPhone/Watch sync does not require iCloud.

![Wristlab feature map: Today, Sleep, Activity, Trends and My Data](docs/feature-dashboard.svg)

Illustrative feature map in Chinese, **not an app screenshot or health data**. Today summarizes readiness, energy and stress; Sleep explains rest; Activity holds editable weekly plans and recorded workout progress; Trends combines health history with manual weight entries and weight goals; My Data controls connections and settings. Watch snapshots, widgets and optional local morning briefs extend the experience.

Weekly planning and weight goals are implemented; real-data matching and interactions still need device acceptance. Plans require confirmation. Weight or deadline differences are not converted into prescribed exercise. See the [proposed display improvements (Chinese)](docs/display-optimization.md); these are recommendations, not shipped UI changes.

## Native App Captures

<table align="center">
<tr><th>iPhone · Today</th><th>Apple Watch · At a glance</th></tr>
<tr>
<td valign="top"><img src="docs/screenshots/iphone.png" width="300" alt="iPhone · synthetic demo data" /></td>
<td valign="top"><img src="docs/screenshots/watch.png" width="180" alt="Apple Watch · synthetic demo data" /></td>
</tr>
</table>

CI captures the running SwiftUI apps with `--demo`. Synthetic health records pass through the same business engine as real records. These are application screenshots, not mockups, and contain no personal health data. The current app interface is in Chinese. See [capture provenance](docs/screenshots/README.md).

## Features

| Feature | Behavior |
| --- | --- |
| Readiness | Personal history over 60 days, requiring 14 valid days; night-first with an explicit daytime fallback |
| Physiological stress | Five-minute buckets, separate sleep/awake baselines, explicit heart-rate-only estimates |
| Body energy | Sleep recharge, activity drain, continuity across midnight, gaps and recalibration |
| Sleep | Source selection, interval deduplication, stages, primary sleep/naps, seven-day debt and timing regularity |
| Activity | Existing workouts, HRR zones, observed load, exertion and historical reference ranges |
| Explanations | Comparison with the personal baseline (raises/lowers and difference), specified tier labels, missing-input reasons, baseline counts, partial quality, coverage, versions and timestamps |
| Phone and Watch | Phone report with the day's energy and stress over sleep and workouts, sleep detail, 7/30-day trends (readiness, sleep, load, nightly HRV, resting heart rate with the personal baseline band) and a last-7-days review; phone-produced Watch snapshots, refresh requests, and energy, readiness, stress and overview complications |
| iPhone widgets | Home screen small/medium and lock screen circular/rectangular/inline widgets with the latest readiness, energy and stress; stale, waiting, cleared and real-zero states follow the complication rules; demo data is never written |
| Morning brief | Opt-in local notification after the first refresh between 05:00 and 14:00 with today's completed main sleep (values hidden by default); once per day, no fixed delivery time |
| Mood logs | On iOS 18+, after an explicit connect, read-only self-reported State of Mind shown next to the physiological stress of the same time; no mood is inferred, no causation is claimed, nothing syncs to the Watch |
| Local controls | Source preferences, fixed analysis time zone, sleep target, cache clearing and offline clear markers |

Real mode starts empty. Reading requires an explicit Apple Health connection. Demo mode is opt-in, visibly synthetic, and isolated from real synchronization caches.

## Run

Install full **Xcode** and its iOS/watchOS platforms. Only the latest Xcode is supported; CI uses Xcode 27. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen), then:

```sh
git clone https://github.com/mirsery/wristlab.git
cd wristlab
brew install xcodegen
./scripts/check.sh
./scripts/build-apple.sh
open Wristlab.xcodeproj
```

Select your signing team for the iPhone, Watch, complication and iPhone widget targets. Physical installation requires paired devices, Developer Mode and signing that supports HealthKit, App Groups and the configured entitlements. When changing bundle IDs, update the Watch companion ID and App Group identifiers as well. See [device setup](docs/development.md).

To preview synthetic data in a simulator, add `--demo` to the scheme's launch arguments. A normal launch never invents health scores.

## Data and models

Health records stay on device with file protection and atomic persistence. There is no self-hosted backend, analytics/advertising SDK, separate registration, subscription or AI upload. Optional Apple CloudKit carries only four interface preferences, subject to capable signing and explicit consent. Watch receives a compact display snapshot, not raw heart-rate series.

Independent Watch reporting is implemented but awaits physical-device acceptance: users explicitly select local Watch or phone-synced reports. Local mode requests read-only HealthKit access and stores its own available records; foreground/manual refresh reuses the same engine without reducing baseline requirements. No raw records or baselines are merged across devices, and no fixed background cadence is promised.

Readiness, stress and body energy are **experimental estimates** with published, versioned formulas. They are not measurements, medical assessments or training prescriptions. PeakWatch's public behavior is a product reference; Wristlab uses original branding, UI and code, has no affiliation, and neither reproduces private formulas nor promises matching scores. HRV v1 uses **SDNN**, not RMSSD. See [sources and differences](specs/000-reference-behavior.md).

Conservative input requirements can leave metrics unavailable: no primary sleep means no initial energy seed; an unobserved gap over30 minutes breaks the energy chain; insufficient daily coverage prevents a complete historical activity target. Missing values never become demo values or default healthy scores.

## Architecture and verification

```text
HealthKit changes → normalized records/sources → sleep and personal baselines
                                              → readiness/stress/load → energy replay
                                              → atomic local report → phone / Watch / widget
```

- `Packages/WristlabCore`: pure Swift domain calculations, reports, transactional storage and snapshot protocol.
- `Apps/iOS`: read-only HealthKit adapter, settings, charts and explanations.
- `Apps/watchOS`: snapshots, refresh requests, producer confirmation and demo mode.
- `Apps/Widgets`: WidgetKit energy, readiness, stress and overview complications.
- `Apps/PhoneWidgets`: iPhone home screen and lock screen widgets.
- `project.yml`: source configuration for the generated Xcode project.

CI validates specifications, tests domain behavior, builds both simulator targets and captures screenshots. Twelve numeric fixtures come from the spec; see [validation coverage](docs/validation.md) for additional cases. **Simulator builds and screenshots do not establish physical HealthKit access, background delivery, signing or complication installation.**

AI, food recognition, workout recording/courses, health-data cloud replication, monetization and App Store distribution are outside v1. The optional interface-preference cloud extension does not restore weights, goals or plans. See the [spec index](specs/README.md) for scope.

## Contributing

Update specs and acceptance criteria before implementation. Use PRs; `main` requires both CI checks and rejects force pushes/deletion. [AGENTS.md](AGENTS.md) · [CONTRIBUTING.md](CONTRIBUTING.md) · [PRIVACY.md](PRIVACY.md)

MIT License. Use synthetic data in issues, logs, tests and screenshots. Never commit health exports or signing assets.

Development follows [STDD](docs/stdd.md): Spec + Test driven delivery with four phases and three confirmation gates. Use `./scripts/stdd` as the project CLI.

## Apple Watch complications

Open Settings → Apple Watch → Complications on iPhone, or More → Complications on Watch, for setup instructions and visibly synthetic previews. Energy, readiness and stress support circular, rectangular, inline and corner slots; the overview uses a rectangular slot. Available slots depend on the selected system face.

Live complications use only the phone's validated snapshot. Missing, calibrating and stale data never become a default score. Stale values are hidden. A single-metric tap opens its report; the overview opens the Watch home screen. External complication links leave demo mode. Refresh timing is controlled by watchOS. No preconfigured .watchface file is bundled.

Local builds and domain tests passed; consult the [validation record](docs/validation.md) for actual face installation, cold/warm navigation and background delivery evidence. In-app illustrations do not establish successful face installation.

[Local guide screenshots](docs/screenshots/watch-face/README.md) show a labeled synthetic preview, not an installed system watch face.
