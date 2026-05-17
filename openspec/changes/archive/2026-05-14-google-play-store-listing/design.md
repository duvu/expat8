## Context

The Flutter app targets Android via `mobile/android/`. The Gradle build (`build.gradle.kts`) is already structured with a `release` signing config that reads from `~/keystores/key.properties` — the keystore infrastructure is partially in place. The current `applicationId` is `com.example.expat8_language_app` and the `android:label` is the raw package name; neither is suitable for Play Store submission.

The backend does not use the package name; clients authenticate with `APP_CREDENTIAL_APP_ID` and `APP_CREDENTIAL_SECRET` compiled in via `--dart-define`. Changing the package name has no backend impact.

## Goals / Non-Goals

**Goals:**
- Replace the placeholder package name with a valid production ID (`vn.x51.expat8`)
- Set a user-visible app name (`Expat8 – Learn English`)
- Align version code/name to a 1.0.0 baseline
- Generate a signed Android App Bundle (`.aab`) as the Play Store upload artifact
- Define store listing copy and asset specifications required to submit the app
- Document the privacy policy data-collection statements

**Non-Goals:**
- iOS App Store listing (separate change)
- Automated CI/CD pipeline for Play Store upload (can follow later)
- In-app purchase or monetization configuration
- A/B testing or Play Store Experiments

## Decisions

### D1: Application ID — `vn.x51.expat8`

`com.example.*` is explicitly blocked by Play Console. The reverse-DNS of the deployment domain gives `vn.x51.expat8`, which is valid, memorable, and aligns with the production backend host. Alternative `com.expat8.app` was considered but we don't own `expat8.com`.

### D2: Keystore location — `~/keystores/` (outside repo)

The Gradle file already reads from `~/keystores/key.properties`. Keeping the keystore outside the repo avoids accidental secret commits. The `key.properties` file must never be committed; it is already structured to be operator-supplied. The keystore itself (`expat8-release.jks`) lives alongside the properties file.

### D3: Upload format — App Bundle (`.aab`) not APK

Google Play requires `.aab` for new apps. The `flutter build appbundle --release` command produces this directly. The existing APK build command (`flutter build apk --release`) is retained for sideload/test builds only.

### D4: `namespace` vs `applicationId` — keep in sync

Android Gradle requires `namespace` (for R class generation) and `applicationId` to match for a single-variant app. Both will be set to `vn.x51.expat8`. The `android:package` attribute in `AndroidManifest.xml` is derived from `namespace` automatically by AGP.

### D5: Version baseline — `1.0.0+1`

`pubspec.yaml` currently reads `0.1.0+1`. For the first Play Store release set `version: 1.0.0+1` (versionName `1.0.0`, versionCode `1`). Subsequent releases increment versionCode monotonically.

### D6: Store listing copy — English only at launch

The app teaches English; the primary audience is non-native English speakers but the store listing itself will be in English. Localised listings (Vietnamese) can be added later via Play Console without a code change.

## Risks / Trade-offs

- **[Risk] Existing installs break after package rename** → Mitigation: there are no prior Play Store installs; the package name has never been published. No migration needed.
- **[Risk] Keystore loss = permanent inability to update app** → Mitigation: back up `expat8-release.jks` and `key.properties` to a secure location (password manager or cloud secret store) before the first upload. Document backup location in the ops runbook.
- **[Risk] `~/keystores/key.properties` not present on CI** → Mitigation: CI is out of scope for this change. If added later, the file should be injected from a secret store.
- **[Risk] Google Play review rejects content** → Mitigation: content rating is "Everyone", no UGC, no ads. Low rejection risk. Privacy policy must be a publicly accessible URL before submission.

## Migration Plan

1. Generate release keystore → save to `~/keystores/expat8-release.jks` and write `~/keystores/key.properties`
2. Update `applicationId` and `namespace` in `build.gradle.kts`
3. Update `android:label` in `AndroidManifest.xml`
4. Update `version` in `pubspec.yaml` to `1.0.0+1`
5. Run `flutter build appbundle --release …` to verify signing works
6. Prepare visual assets (icon, feature graphic, screenshots) per Play Store specs
7. Create Play Console app entry, upload `.aab` to Internal Testing track, fill in store listing

**Rollback:** The package name change is irreversible once published to Play Store. Before the first production release, rolling back is trivial (revert `build.gradle.kts`). After publishing, the package name is locked forever — this makes step 2 a one-way door.

## Open Questions

- What publicly accessible URL will host the privacy policy? (GitHub Pages or a backend-hosted `/privacy` page are candidates)
- Will the first release target Internal Testing only, or go directly to Production?
