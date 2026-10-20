# Wristlab agent rules

## Workflow
1. Read `specs/README.md` and the spec for the feature before editing code. Change behavior and acceptance criteria in the spec first.
2. Keep the change scoped to one acceptance criterion or a coherent group. Preserve unrelated local edits.
3. Run `scripts/check.sh`. Changes to app targets also require `scripts/build-apple.sh` on a Mac with full Xcode. Report unavailable checks explicitly.
4. In the handoff, list behavior changed, spec IDs covered, checks run, and remaining gaps. A scaffold or simulator build does not prove device installation.

## Boundaries
- `Packages/WristlabCore` contains platform-independent models and scoring logic. Apple APIs belong in app adapters; views consume models rather than querying HealthKit directly.
- Use SwiftUI for iOS/watchOS. Add dependencies only with a documented need and license review.
- Demo values are visibly marked. Missing health data remains missing; never replace missing data with a normal score or silently use demo values.
- Scores are experimental estimates. Formula, baseline, time window, units, model version, and missing-data policy must appear in `specs/002-scoring.md` before implementation.
- Read-only HealthKit access is the default. Health data stays on device; tests, logs, issues, fixtures, and commits contain synthetic data only.
- Empty HealthKit reads do not prove permission denial. Treat authorization completion and data availability separately.
- Watch snapshots include generation time and source. Use system scheduling for complications and show stale state; promise no fixed background refresh interval.
- Never commit signing certificates, provisioning profiles, team-specific signing settings, credentials, or real health exports.
- Use original branding and assets. PeakWatch is a functional reference, not a source of proprietary code, artwork, or scoring claims.

## Context pointers
- Product scope and feature acceptance: `specs/001-product.md`.
- Health access, lifecycle, and sync changes: `specs/003-health-and-sync.md`.
- Module boundaries and technical decisions: `docs/architecture.md`.
- CI, PRs, branch policy: `CONTRIBUTING.md`.
- Device setup and signing: `docs/development.md`.
