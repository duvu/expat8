## Why

The mobile app can already produce a release APK, but the release contract only treats the Play Store bundle as the primary artifact. We need a tracked production APK path so sideloading and internal distribution are reproducible instead of relying on ad hoc build commands.

## What Changes

- Make the production Android APK a first-class release artifact alongside the existing AAB flow.
- Require the release APK to be built with the same production `--dart-define` inputs and release keystore as the bundle.
- Keep the current Android package identity, signing configuration, and Play Store bundle flow unchanged.
- Update release verification to include the APK output path and install smoke check.

## Capabilities

### New Capabilities

### Modified Capabilities

- `mobile-release-android`: make the signed production APK an explicit supported release artifact while preserving the existing Play Store AAB workflow.

## Impact

- Mobile Android release packaging and artifact outputs.
- Release verification and sideload smoke testing.
- Release-facing documentation or checklists that mention Android build commands.
- No app runtime behavior, backend API, or data model changes.
