## 1. Release Artifact Definition

- [x] 1.1 Update the Android release spec to explicitly require a signed production APK in addition to the existing AAB.
- [x] 1.2 Confirm the release build command set uses the same production `--dart-define` values for both APK and AAB.

## 2. Release Verification

- [x] 2.1 Verify `flutter build apk --release` produces `build/app/outputs/flutter-apk/app-release.apk`.
- [x] 2.2 Verify the APK installs successfully on an Android emulator or physical device.
- [x] 2.3 Verify the existing signed release bundle flow still produces `build/app/outputs/bundle/release/app-release.aab`.

## 3. Documentation And Checklist

- [x] 3.1 Update release-facing documentation or checklists to mention the production APK artifact.
- [x] 3.2 Record the final build command used for the production APK verification.
