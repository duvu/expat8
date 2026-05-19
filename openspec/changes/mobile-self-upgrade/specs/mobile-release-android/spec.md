## MODIFIED Requirements

### Requirement: Production release build produces a distributable APK and AAB
The release build process SHALL produce both a signed APK and AAB suitable for distribution. After a successful build, the operator MAY upload the APK to the backend release management API to make it available for in-app upgrades.

#### Scenario: Operator builds a release APK
- **WHEN** an operator runs `flutter build apk --release --dart-define=BACKEND_BASE_URL=<url> --dart-define=APP_CREDENTIAL_APP_ID=<id> --dart-define=APP_CREDENTIAL_SECRET=<secret> --dart-define=NEW_WORD_TIMEOUT_SECONDS=5 --dart-define=APP_LOG_LEVEL=info` with `JAVA_HOME` set and `~/keystores/key.properties` present
- **THEN** the build succeeds and produces `build/app/outputs/flutter-apk/app-release.apk`

#### Scenario: Operator registers release with backend
- **WHEN** an operator uploads the built APK to `POST /v1/admin/releases` with the version_code from `pubspec.yaml`, version_name, and platform "android"
- **THEN** the backend stores the release and it becomes available for in-app upgrade checks by mobile clients
