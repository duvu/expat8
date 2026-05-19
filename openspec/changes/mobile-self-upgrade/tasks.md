## 1. Backend release store

- [ ] 1.1 Create `backend/src/release_store.js` with in-memory `ReleaseStore` class: `createRelease()`, `getLatestRelease(platform)`, `listReleases()`, `deleteRelease(id)`, auto-prune to 5 per platform
- [ ] 1.2 Create `backend/src/postgres_release_store.js` extending the store for Postgres-backed metadata (reuse pool from runtime) with file storage on disk under `RELEASE_STORAGE_DIR`
- [ ] 1.3 Add `release_versions` table to `backend/db/schema.sql` (id, platform, version_code, version_name, file_path, file_size_bytes, sha256, created_at)
- [ ] 1.4 Add numbered migration in `backend/db/migrations/` for the `release_versions` table

## 2. Backend release routes

- [ ] 2.1 Create `backend/src/routes/releases.js` with admin upload `POST /v1/admin/releases` (multipart form: file + version_code + version_name + platform), admin list `GET /v1/admin/releases`, admin delete `DELETE /v1/admin/releases/:id`
- [ ] 2.2 Add public `GET /v1/releases/latest?platform=android` returning latest release metadata (app-credential auth only)
- [ ] 2.3 Add public `GET /v1/releases/:id/download` streaming the APK binary (app-credential auth only)
- [ ] 2.4 Wire release routes into `backend/src/app.js` and `backend/src/runtime.js` (create store, pass to router)

## 3. Backend tests and contract

- [ ] 3.1 Add `backend/test/release_store.test.js` covering upload, prune, latest, list, delete, and unknown-ID cases
- [ ] 3.2 Update `contracts/api.md` with the new release endpoints (request/response shapes, auth requirements)
- [ ] 3.3 Run `cd backend && npm test`

## 4. Mobile upgrade check API

- [ ] 4.1 Add `fetchLatestRelease(platform)` to `mobile/lib/src/api/backend_api_client.dart` calling `GET /v1/releases/latest?platform=android`
- [ ] 4.2 Add `downloadRelease(id, onProgress)` to `BackendApiClient` that streams the APK binary to a temporary file and reports progress
- [ ] 4.3 Create `mobile/lib/src/models/release_info.dart` model class with version_code, version_name, file_size_bytes, sha256, id, created_at

## 5. Mobile upgrade check screen

- [ ] 5.1 Create `mobile/lib/src/ui/upgrade_check_screen.dart` showing current version, latest version, download button (or up-to-date message), progress indicator during download, and error/retry state
- [ ] 5.2 Add "Check for updates" `ListTile` in `LearningDrawer` in `mobile/lib/src/ui/learning_screen.dart` that navigates to the upgrade check screen
- [ ] 5.3 Add `REQUEST_INSTALL_PACKAGES` permission to `mobile/android/app/src/main/AndroidManifest.xml`
- [ ] 5.4 Implement APK install launch using Android intent (platform channel or `open_filex` package) after download completes

## 6. Mobile tests

- [ ] 6.1 Add `mobile/test/upgrade_check_screen_test.dart` widget test covering: newer version available shows download button, already up-to-date shows message, error state shows retry
- [ ] 6.2 Add `mobile/test/backend_api_client_test.dart` cases for `fetchLatestRelease` response parsing
- [ ] 6.3 Run `cd mobile && flutter test`

## 7. End-to-end verification

- [ ] 7.1 Manually verify: upload a test APK via admin API, confirm it appears in `GET /v1/admin/releases` and `GET /v1/releases/latest?platform=android`
- [ ] 7.2 Manually verify: open the upgrade check screen on the emulator, confirm it shows version comparison and can download the APK
- [ ] 7.3 Manually verify: upload 6 releases, confirm only 5 remain after the 6th upload
