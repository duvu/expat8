## 1. Release Keystore Setup

- [x] 1.1 Generate release keystore: `keytool -genkey -v -keystore ~/keystores/expat8-release.jks -alias expat8 -keyalg RSA -keysize 2048 -validity 10000`
- [x] 1.2 Create `~/keystores/key.properties` with `storeFile`, `storePassword`, `keyAlias`, `keyPassword` fields pointing to the generated keystore
- [ ] 1.3 Back up `expat8-release.jks` and `key.properties` to a secure location (password manager or cloud secret store)
- [x] 1.4 Verify `~/keystores/key.properties` is NOT tracked by git (`git check-ignore ~/keystores/key.properties` or confirm it is outside the repo)

## 2. Android App Identity

- [x] 2.1 In `mobile/android/app/build.gradle.kts`: change `namespace` from `"com.example.expat8_language_app"` to `"vn.x51.expat8"`
- [x] 2.2 In `mobile/android/app/build.gradle.kts`: change `applicationId` from `"com.example.expat8_language_app"` to `"vn.x51.expat8"`
- [x] 2.3 In `mobile/android/app/src/main/AndroidManifest.xml`: change `android:label` from `"expat8_language_app"` to `"Expat8 – Learn English"`
- [x] 2.4 In `mobile/pubspec.yaml`: change `version` from `0.1.0+1` to `1.0.0+1`
- [x] 2.5 Run `flutter build appbundle --release --dart-define=BACKEND_BASE_URL=https://expat8.x51.vn --dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app --dart-define=APP_CREDENTIAL_SECRET=expat8-mobile-secret` (with `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64`) and confirm the build succeeds and produces `build/app/outputs/bundle/release/app-release.aab`
- [x] 2.6 Inspect the `.aab` manifest (e.g., via `bundletool dump manifest --bundle=app-release.aab`) and confirm `applicationId` is `vn.x51.expat8` and `versionCode`/`versionName` are `1`/`1.0.0`

## 3. Store Listing Copy

- [x] 3.1 Write final store listing title: `Expat8 – Learn English` (confirm ≤50 chars)
- [x] 3.2 Write short description (≤80 chars): e.g., `"Swipe through flashcards and fill-in-the-blank exercises to build your English vocabulary."`
- [x] 3.3 Write full description (≤4000 chars) covering: core swipe-based learning, FITB mode, spaced repetition, exam mode, speaking drills, target audience (expats and intermediate English learners)
- [x] 3.4 Prepare a keyword list (up to 7 Play Store tags): e.g., vocabulary, English, flashcards, SRS, language learning, IELTS, expat

## 4. Visual Assets

- [ ] 4.1 Export app icon as 512×512 px PNG with solid background — save as `mobile/assets/store/icon-512.png`
- [ ] 4.2 Create feature graphic 1024×500 px PNG — save as `mobile/assets/store/feature-graphic.png`
- [x] 4.3 Take at least 2 phone screenshots on a 16:9 or 19.5:9 device/emulator showing: (a) vocabulary card session, (b) FITB card — save as `mobile/assets/store/screenshot-01.png`, `screenshot-02.png`
- [ ] 4.4 Optionally take a 3rd screenshot showing the exam or home screen

## 5. Privacy Policy

- [x] 5.1 Write `docs/privacy-policy.md` covering: device ID collection, learning progress stored locally and synced to backend, audio recording for speaking drill, no third-party advertising SDKs
- [ ] 5.2 Publish the privacy policy to a publicly accessible URL (e.g., `https://expat8.x51.vn/privacy` or a GitHub Pages page) and confirm it returns HTTP 200
- [ ] 5.3 Record the privacy policy URL for entry into Play Console

## 6. Play Console Submission

- [ ] 6.1 Create a new app in Play Console with package name `vn.x51.expat8` and default language English (US)
- [ ] 6.2 Upload `app-release.aab` to the Internal Testing track
- [ ] 6.3 Fill in store listing: title, short description, full description, icon, feature graphic, screenshots
- [ ] 6.4 Complete content rating questionnaire — select "Everyone" / no mature content
- [ ] 6.5 Enter privacy policy URL in the App Content section
- [ ] 6.6 Add at least one internal tester email; publish to Internal Testing and confirm the app is installable via the internal test link

## 7. Verification

- [ ] 7.1 Install the Internal Testing build from Play Store on a real device and confirm the app label reads `Expat8 – Learn English`
- [ ] 7.2 Confirm the app launches, authenticates with the backend, and shows vocabulary cards
- [ ] 7.3 Confirm the `applicationId` shown in device Settings → Apps matches `vn.x51.expat8`
