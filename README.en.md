<div align="center">

# Wristlab

**A clearer view of your day.**

A local-first health trends lab for iPhone and Apple Watch.

[简体中文](README.md) · [Specifications](specs/README.md) · [Development](docs/development.md) · [Validation](docs/validation.md)

![CI](https://github.com/mirsery/wristlab/actions/workflows/ci.yml/badge.svg)
![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![Platforms](https://img.shields.io/badge/iOS-17%2B%20%7C%20watchOS%2010%2B-222)
![License](https://img.shields.io/badge/License-MIT-8DEDB6)

</div>

## Preview

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
| Explanations | Missing-input reasons, baseline counts, partial quality, coverage, versions and timestamps |
| Apple Watch | Phone-produced snapshots, refresh requests and a body-energy complication |
| Local controls | Source preferences, fixed analysis time zone, sleep target, cache clearing and offline clear markers |

Real mode starts empty. Reading requires an explicit Apple Health connection. Demo mode is opt-in, visibly synthetic, and isolated from real synchronization caches.

## Run

Install full **Xcode** and its iOS/watchOS platforms. CI uses Xcode16.4. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen), then:

```sh
git clone https://github.com/mirsery/wristlab.git
cd wristlab
brew install xcodegen
./scripts/check.sh
./scripts/build-apple.sh
open Wristlab.xcodeproj
```

Select your signing team for the iPhone, Watch and Widget targets. Physical installation requires paired devices, Developer Mode and signing that supports HealthKit, App Groups and the configured entitlements. When changing bundle IDs, update the Watch companion ID and App Group identifiers as well. See [device setup](docs/development.md).

To preview synthetic data in a simulator, add `--demo` to the scheme's launch arguments. A normal launch never invents health scores.

## Data and models

Health records stay on device with file protection and atomic persistence. There is no backend, analytics/advertising SDK, account, subscription or AI upload. Watch receives a compact display snapshot, not raw heart-rate series.

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
- `Apps/Widgets`: WidgetKit body-energy complication.
- `project.yml`: source configuration for the generated Xcode project.

CI validates specifications, tests domain behavior, builds both simulator targets and captures screenshots. Twelve numeric fixtures come from the spec; see [validation coverage](docs/validation.md) for additional cases. **Simulator builds and screenshots do not establish physical HealthKit access, background delivery, signing or complication installation.**

AI, food recognition, workout recording/courses, cloud sync, monetization and App Store distribution are outside v1. See the [spec index](specs/README.md) for scope.

## Contributing

Update specs and acceptance criteria before implementation. Use PRs; `main` requires both CI checks and rejects force pushes/deletion. [AGENTS.md](AGENTS.md) · [CONTRIBUTING.md](CONTRIBUTING.md) · [PRIVACY.md](PRIVACY.md)

MIT License. Use synthetic data in issues, logs, tests and screenshots. Never commit health exports or signing assets.
