## Why

The mobile app currently has no mechanism for self-upgrade. Users must manually find and install new APK versions, which creates friction for distributing updates outside of Google Play. Adding an in-app version check and download/install flow lets us push updates directly to learners and keep the installed base current without app-store dependency.

## What Changes

- Add a backend API for managing mobile release versions (upload metadata, list versions, download APK binary).
- Backend retains only the 5 most recent release versions per platform; older releases are automatically pruned.
- Add a mobile UI button (accessible from the app drawer) to check whether a newer version is available.
- When a newer version exists, the app downloads the APK and triggers the Android package installer flow.
- Display current app version and latest available version in the upgrade check screen.

## Capabilities

### New Capabilities
- `mobile-release-management`: Backend API for storing, listing, pruning, and serving mobile release versions (APK files and metadata). Retains at most 5 latest versions.
- `mobile-in-app-upgrade`: Mobile UI and logic for checking the latest release, downloading the APK, and initiating the Android install flow.

### Modified Capabilities
- `mobile-release-android`: The release build process now includes an optional upload step to register the new version with the backend release management API.

## Impact

- `backend/src/routes/` — new release management routes
- `backend/src/` — new release store (file-based or Postgres-backed)
- `backend/db/schema.sql` or migration — release_versions table (if Postgres)
- `contracts/api.md` — new endpoints documented
- `mobile/lib/src/ui/` — new upgrade check screen
- `mobile/lib/src/api/backend_api_client.dart` — new API methods
- `mobile/android/app/src/main/AndroidManifest.xml` — REQUEST_INSTALL_PACKAGES permission
- `mobile/pubspec.yaml` — possibly `open_filex` or similar package for APK install
