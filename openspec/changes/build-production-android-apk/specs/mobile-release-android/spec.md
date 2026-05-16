## MODIFIED Requirements

### Requirement: Mobile project SHALL produce Android release build
The mobile codebase MUST support Android release packaging that compiles the application with release profile and produces distributable artifacts. The primary release artifact for Play Store distribution is a signed Android App Bundle (`.aab`); a signed release APK MUST also be produced for sideload testing and internal distribution. Both release outputs MUST use the same production `--dart-define` values and the same operator-managed release keystore.

#### Scenario: Operator builds Android release bundle
- **WHEN** an operator runs `flutter build appbundle --release --dart-define=BACKEND_BASE_URL=<url> --dart-define=APP_CREDENTIAL_APP_ID=<id> --dart-define=APP_CREDENTIAL_SECRET=<secret> --dart-define=NEW_WORD_TIMEOUT_SECONDS=5 --dart-define=APP_LOG_LEVEL=info` with `JAVA_HOME` set and `~/keystores/key.properties` present
- **THEN** the build completes successfully and outputs `build/app/outputs/bundle/release/app-release.aab`

#### Scenario: Operator builds Android release APK
- **WHEN** an operator runs `flutter build apk --release --dart-define=BACKEND_BASE_URL=<url> --dart-define=APP_CREDENTIAL_APP_ID=<id> --dart-define=APP_CREDENTIAL_SECRET=<secret> --dart-define=NEW_WORD_TIMEOUT_SECONDS=5 --dart-define=APP_LOG_LEVEL=info` with `JAVA_HOME` set and `~/keystores/key.properties` present
- **THEN** the build completes successfully and outputs `build/app/outputs/flutter-apk/app-release.apk`

### Requirement: Release build SHALL produce signed Android artifacts
The release build commands MUST produce signed release artifacts using the operator-managed keystore and MUST NOT be signed with a debug certificate.

#### Scenario: Signed app bundle is produced
- **WHEN** an operator runs `flutter build appbundle --release` with the same production define set and valid keystore configuration
- **THEN** `build/app/outputs/bundle/release/app-release.aab` is created and is signed with the release key

#### Scenario: Signed app APK is produced
- **WHEN** an operator runs `flutter build apk --release` with the same production define set and valid keystore configuration
- **THEN** `build/app/outputs/flutter-apk/app-release.apk` is created and is signed with the release key

#### Scenario: App bundle is accepted by Play Console
- **WHEN** the `.aab` is uploaded to Play Console (Internal Testing track)
- **THEN** Play Console accepts the upload and shows the correct `versionCode` and `versionName`

### Requirement: Release validation SHALL include gesture-based study flow
Before release publication, Android validation MUST verify the gesture-only learning workflow, including all four swipe directions and card transition outcomes.

#### Scenario: Gesture smoke validation passes
- **WHEN** release candidate is executed on emulator or device
- **THEN** right-to-left, left-to-right, bottom-to-top, and top-to-bottom swipes each trigger the expected learning intent without runtime crash

### Requirement: Release APK SHALL be installable on target devices
The signed release APK MUST be installable on emulator or physical devices without requiring a debug certificate or debug signing config.

#### Scenario: Emulator install succeeds
- **WHEN** `build/app/outputs/flutter-apk/app-release.apk` is installed on an Android emulator
- **THEN** the package installs successfully and launches the production app

#### Scenario: Device sideload succeeds
- **WHEN** `build/app/outputs/flutter-apk/app-release.apk` is installed on a physical Android device
- **THEN** the package installs successfully and launches the production app
