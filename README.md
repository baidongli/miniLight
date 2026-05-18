# miniLight

Free film camera light meter. Reflective metering through the device camera —
a free, cross-platform (iOS + Android) alternative to paid meter apps.

## What it does

- Live reflective metering from the camera preview
- Spot / center-weighted / average metering modes
- Tap-to-meter: touch anywhere on the preview to meter that exact spot
- Aperture-priority or shutter-priority exposure solving
- Full / half / third stop scales
- Film stock presets with reciprocity-failure correction for long exposures
- One- and two-point calibration against a known meter or the Sunny-16 rule
- Settings persisted across launches

## Architecture

Layered so the exposure logic is pure, testable Dart with no Flutter or
platform dependency — the same core runs unchanged on iOS and Android.

```
lib/
  core/                 pure Dart, fully unit tested
    exposure/           EV math, value scales, film stocks, solver
    metering/           luminance sampling, calibration model
  services/             camera adapter (camera plugin -> scene EV)
  state/                MeterController (settings + persistence)
  ui/                   screens + widgets
test/                   unit tests for the core
```

The `camera` plugin does not expose per-frame exposure metadata, so the
camera is exposure-locked and a calibration model maps measured luma to EV.
Anchor it once against a trusted reference (or Sunny-16) for accurate
absolute readings.

## Run locally

Native platform folders are generated on demand (kept out of git):

```bash
flutter create . --platforms=android,ios --project-name minilight --org com.minilight
# Android: add to android/app/src/main/AndroidManifest.xml above <application>:
#   <uses-permission android:name="android.permission.CAMERA" />
# iOS: add to ios/Runner/Info.plist:
#   <key>NSCameraUsageDescription</key>
#   <string>miniLight uses the camera to meter light.</string>
flutter pub get
flutter test
flutter run
```

## Automated Android APK

`.github/workflows/android-apk.yml` builds a release APK on every push to
`main` or any `claude/**` branch (and via manual dispatch). It regenerates
the Android scaffolding, patches the camera permission, runs analyze +
tests, and builds `flutter build apk --release`.

The APK is published two ways:

- **GitHub Release** — each run creates a release tagged `build-<n>` with
  the `.apk` attached and marked as *latest*. Grab it from the repo's
  **Releases** page (the easy, shareable download link).
- **Workflow artifact** — also uploaded under the run's *Artifacts*
  section as `minilight-release-apk` (a zip).

The APK is debug-signed (no keystore configured), which is fine for
sideloading and testing. Add a release keystore + signing config before
shipping to the Play Store.
