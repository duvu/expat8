## ADDED Requirements

### Requirement: Release build SHALL produce a signed Android App Bundle
The release build command MUST produce a signed `.aab` artifact using `flutter build appbundle --release` with the required `--dart-define` flags. The resulting bundle MUST be signed with the release keystore (see `android-app-identity` spec) and MUST NOT be signed with a debug certificate.

#### Scenario: Signed app bundle is produced
- **WHEN** an operator runs `flutter build appbundle --release` with valid keystore configuration
- **THEN** `build/app/outputs/bundle/release/app-release.aab` is created and is signed with the release key

#### Scenario: App bundle is accepted by Play Console
- **WHEN** the `.aab` is uploaded to Play Console (Internal Testing track)
- **THEN** Play Console accepts the upload and shows the correct `versionCode` and `versionName`

## MODIFIED Requirements

### Requirement: Mobile project SHALL produce Android release build
The mobile codebase MUST support Android release packaging that compiles the application with release profile and produces a distributable artifact. The primary release artifact for Play Store distribution is a signed Android App Bundle (`.aab`); a release APK MAY also be produced for sideload testing.

#### Scenario: Operator builds Android release bundle
- **WHEN** an operator runs `flutter build appbundle --release --dart-define=BACKEND_BASE_URL=<url> --dart-define=APP_CREDENTIAL_APP_ID=<id> --dart-define=APP_CREDENTIAL_SECRET=<secret>` with `JAVA_HOME` set and `~/keystores/key.properties` present
- **THEN** the build completes successfully and outputs `build/app/outputs/bundle/release/app-release.aab`

### Requirement: Release validation SHALL include gesture-based study flow
Before release publication, Android validation MUST verify the gesture-only learning workflow, including all four swipe directions and card transition outcomes.

#### Scenario: Gesture smoke validation passes
- **WHEN** release candidate is executed on emulator or device
- **THEN** right-to-left, left-to-right, bottom-to-top, and top-to-bottom swipes each trigger the expected learning intent without runtime crash
