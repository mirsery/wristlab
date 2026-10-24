# Specification baseline

Existing business-v1 remains authoritative in [specs/](../../specs/README.md). New STDD deltas are archived here. Update existing business definitions when changing them; see [migration policy](../../docs/stdd.md).

## Watch daily care — merged 2026-10-24

- [Care presentation](watch-care-presentation/spec.md): WCP-001–005.
- [Read-only daily activity](watch-daily-activity/spec.md): WDA-001–005.
- [Private care state](watch-care-state/spec.md): WCS-001–005.

Source: [2026-10-23-watch-daily-care](../archive/2026-10-23-watch-daily-care/delivery.md). Code/simulator Gate 3 was accepted with disclosed platform gaps; merging a specification does not certify device behavior. Canonical baselines are retained in .stdd/canonical and the archive.

## Phone today care — merged 2026-10-24

- [Phone today care](phone-today-care/spec.md): PTC-001–006; [delivery](../archive/2026-10-24-phone-today-care/delivery.md).

Gate 3 explicitly accepted code and simulator validation only: 254 Swift tests, 15 simulator UI tests, both app builds and component probes passed. Real health access, physical devices, full VoiceOver, system background scheduling and performance remain unverified. No device operation, data deletion, Git commit/tag/push or iCloud enablement is included in this archive.

## Accepted fixes — merged 2026-10-24

- [Daily activity calendar contract](watch-daily-activity/spec.md): preserves WDA-001–005, adds ACAL-001–003; [delivery](../archive/2026-10-24-watch-activity-calendar-crash/delivery.md).
- [Phone health connection and local feedback](phone-health-connection/spec.md): PHC-001–007; [delivery](../archive/2026-10-24-phone-health-connection/delivery.md).

Gate 3 was explicitly accepted for these two fault fixes. Device feedback confirmed phone2404 updated its local report and Watch2402 no longer crashed on opening pages. Other health types/scoring, activity values, complications, background operation and performance remain unaudited; local archive does not imply Git commit, push or release.

## 2406 fixes — merged 2026-10-24

- [Phone today care layout](phone-today-care/spec.md): adds PCL-001–004 (equal-height cards, today status-bar backdrop, bottom clearance); [report](../archive/2026-10-24-phone-care-layout/test-report.md).
- [Watch runtime stability](watch-runtime-stability/spec.md): new capability, WRX-001–003 (WatchConnectivity refresh callbacks stay nonisolated); [report](../archive/2026-10-24-watch-refresh-exit/test-report.md).

Gate 3 was accepted after the user confirmed on device that the phone layout is fixed and the Watch no longer crashes on 2406. VoiceOver, home-button devices, iOS 17–26 and a separate page-switch check remain unverified; local archive does not imply release.
