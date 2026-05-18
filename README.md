# miniLight

**v0.0.1** — free, cross-platform (iOS + Android) film camera light meter.
A free alternative to paid meter apps.

## Features

- Three metering sources:
  - **Camera** — reflective metering from the preview (exposure-locked +
    calibration model)
  - **Real (sensor data)** — native Camera2 / AVFoundation reads the
    camera's own exposure metadata for a *calibration-free absolute EV*
  - **Incident (lux)** — Android ambient-light sensor
- Spot / center-weighted / average modes + **tap-to-meter** (touch any
  point on the preview)
- Aperture- or shutter-priority solving, full / half / third stops
- **Camera body profiles** — snap to the exact shutter speeds a given
  body actually has (Leica M, Hasselblad, FM2, K1000…)
- **Compensations**: push/pull, filter factor, bellows (direct or from
  focal/extension), exposure-compensation dial
- **Zone System** placement (place a reading on any zone 0–10)
- Film presets + reciprocity correction; **add custom films**
- **Shot log**: rolls, per-frame log with GPS, CSV export/share
- Reading **hold/lock**, highlight/shadow clipping warning
- English / 简体中文, settings persisted

## Architecture

Layered so the exposure logic is pure, testable Dart — the same core runs
unchanged on iOS and Android.

```
lib/
  core/        pure Dart, fully unit tested
    exposure/  EV math, scales, film, camera bodies, adjustments, solver
    metering/  luminance, calibration, absolute-EV, incident-EV, geometry
    log/       roll + shot-log model, CSV
  services/    camera, native exposure channel, light sensor, GPS, rolls
  state/       MeterController (all settings + persistence)
  ui/          screens + widgets
  l10n/        in-app en/zh strings
native/        committed Camera2 (Kotlin) + AVFoundation (Swift) plugin
scripts/       CI native-injection scripts
test/          unit tests for the whole core
```

**Real metering**: the `camera` plugin exposes no per-frame exposure
metadata, so a small native plugin (`native/android`, `native/ios`) runs
its own metering session, streams `{exposureTime, ISO, aperture, region
luma}`, and `AbsoluteEvCalculator` derives an absolute EV with no manual
calibration. The native sources are committed under `native/` and injected
into the CI-generated platform projects by `scripts/inject_native_*.sh`
(this keeps the repo lean while still version-controlling the native code).

## Run locally

```bash
flutter create . --platforms=android,ios --project-name minilight --org com.minilight
bash scripts/inject_native_android.sh   # on macOS also: scripts/inject_native_ios.sh
flutter pub get
flutter test
flutter run
```

## CI builds

`.github/workflows/android-apk.yml` runs on every push to `main` /
`claude/**` (and manual dispatch):

- **android** job → analyze + test + `flutter build apk --release`
- **ios** job → `flutter build ios --release --no-codesign`, zips the
  unsigned `Runner.app`
- **release** job → publishes a `build-<n>` GitHub Release (marked latest)
  with the APK and the iOS zip attached

The APK is debug-signed and the iOS build is unsigned — fine for testing.
For release: **`docs/PLAY_GUIDE.md`** is the complete step-by-step Google
Play walkthrough; `docs/STORE_SETUP.md` covers both stores at a glance.
