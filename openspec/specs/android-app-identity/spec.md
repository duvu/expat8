## Purpose
Define the production Android application identity: package name, display name, version, and release signing configuration.

## Requirements

### Requirement: Android applicationId SHALL be the production package name
The Android `applicationId` and `namespace` in `build.gradle.kts` MUST be set to `vn.x51.expat8`. The placeholder `com.example.*` namespace MUST NOT appear in any release build.

#### Scenario: Release build uses production applicationId
- **WHEN** an operator runs `flutter build appbundle --release`
- **THEN** the resulting `.aab` manifest contains `applicationId = "vn.x51.expat8"`

### Requirement: App display name SHALL be user-facing
The `android:label` in `AndroidManifest.xml` MUST be set to `Expat8 – Learn English` so users see a meaningful name on their home screen and in the app drawer.

#### Scenario: App label is visible after install
- **WHEN** the signed APK or bundle is installed on a device
- **THEN** the launcher icon label reads `Expat8 – Learn English`

### Requirement: Version SHALL follow semantic 1.0.0 baseline
`pubspec.yaml` MUST declare `version: 1.0.0+1` for the initial Play Store release. `versionCode` (the `+1` suffix) MUST be incremented monotonically with every subsequent release upload.

#### Scenario: Version fields are correct in release build
- **WHEN** the release app bundle is inspected
- **THEN** `versionName` is `1.0.0` and `versionCode` is `1`

### Requirement: Release signing SHALL use an operator-managed keystore
`build.gradle.kts` MUST configure a `release` signing config that reads `storeFile`, `storePassword`, `keyAlias`, and `keyPassword` from `~/keystores/key.properties`. The keystore file and properties file MUST NOT be committed to the repository.

#### Scenario: Release build signs with keystore
- **WHEN** `~/keystores/key.properties` is present and `flutter build appbundle --release` is run
- **THEN** the `.aab` is signed with the key identified in `key.properties` and no debug certificate is used

#### Scenario: Missing keystore fails fast
- **WHEN** `~/keystores/key.properties` does not exist
- **THEN** the Gradle build fails with a clear error before producing any artifact
