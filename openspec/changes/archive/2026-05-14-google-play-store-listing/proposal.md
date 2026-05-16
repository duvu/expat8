## Why

The app is ready for its first public release but cannot be submitted to Google Play under the placeholder identity `com.example.expat8_language_app` — the `com.example` namespace is explicitly rejected by Play Store. Establishing a production app identity and store listing is the final gate before the app can reach real users.

## What Changes

- Rename the Android `applicationId` from `com.example.expat8_language_app` to `vn.x51.expat8`
- Update the Android app label from `expat8_language_app` to `Expat8 – Learn English`
- Update `pubspec.yaml` version to a 1.0.0-ready baseline and align `versionCode` / `versionName`
- Set up a release keystore and configure Gradle signing for the `release` build variant
- Produce a signed Android App Bundle (`.aab`) as the Play Store upload artifact
- Create Play Store listing copy: title, short description (≤80 chars), full description (≤4000 chars)
- Define required visual asset specifications: app icon (512×512 px), feature graphic (1024×500 px), phone screenshots (minimum 2)
- Add a `privacy_policy.md` stub that documents data collection (device ID, learning progress stored locally and synced to backend)
- Set content rating to "Everyone" (no violence, no user-generated content exposed publicly)

## Capabilities

### New Capabilities

- `android-app-identity`: Production `applicationId`, app label, version code/name, keystore signing configuration for release builds
- `play-store-listing`: Store listing copy (title, descriptions, keywords), visual asset specifications, content rating, and privacy policy requirements

### Modified Capabilities

- `mobile-release-android`: Extend to require signed `.aab` output and document the Play Store upload procedure

## Impact

- **Mobile** (`mobile/android/`): `build.gradle.kts` applicationId, `AndroidManifest.xml` label, keystore files and `key.properties`, Gradle signing config
- **Mobile** (`mobile/pubspec.yaml`): version string
- **Backend**: No changes — the backend identifies clients by `app_id`/`secret` headers, not package name
- **CI/Deploy**: Any existing APK build commands must add the `--release` flag and reference keystore; the `LITELLM_API_KEY` and `APP_CREDENTIAL_*` dart-defines remain unchanged
