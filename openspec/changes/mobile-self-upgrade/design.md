## Context

The mobile app is distributed as a signed APK outside of Google Play. Currently there is no in-app mechanism for learners to discover or install newer versions. The operator manually shares APK files or uses side-loading. This creates a long tail of outdated installs and makes it hard to ensure learners benefit from bug fixes and new features promptly.

The backend already serves authenticated APIs for the mobile app and stores file-based artifacts (log archives). Extending it to also store and serve release binaries is a natural fit. The 5-version retention cap keeps disk usage bounded without manual cleanup.

## Goals / Non-Goals

**Goals:**
- Provide a backend API for uploading release metadata + APK binary, listing available versions, and downloading a specific version's APK.
- Automatically prune releases beyond the 5 most recent per platform.
- Provide a mobile UI entry point (drawer button) to check for updates and trigger download/install.
- Show the user their current version vs. the latest available version.
- Use the standard Android package-installer intent to complete the upgrade.

**Non-Goals:**
- Delta/patch updates (full APK download only).
- Auto-update without user consent (always user-initiated).
- iOS support (Android APK only for now).
- Google Play integration or in-app update API.
- Multi-platform (web/desktop) upgrade flows.
- Rollback to older versions from within the app.

## Decisions

### 1. File-based release storage on the backend

Decision: Store APK binaries on the server filesystem under a configurable directory (`RELEASE_STORAGE_DIR`, default `./data/releases`). Metadata (version code, version name, platform, upload timestamp, file size, SHA-256 hash) is stored in-memory for the no-DATABASE_URL case, or in a `release_versions` table when Postgres is available.

Rationale: Matches the existing `FileLogArchiveStore` pattern. APK files are ~15-30 MB; with a 5-version cap that's at most ~150 MB on disk, well within server capacity.

Alternative considered: Store APKs in an object store (S3/MinIO). Rejected because the deployment target (Z440) is a single server and adding an object store dependency increases operational complexity for minimal benefit at this scale.

### 2. Admin-only upload, public-ish version check

Decision:
- `POST /v1/admin/releases` — upload a new release (requires `ADMIN_API_TOKENS`).
- `GET /v1/releases/latest?platform=android` — returns metadata of the latest release (requires app credentials only, no user session).
- `GET /v1/releases/:id/download` — serves the APK binary (requires app credentials only).
- `GET /v1/admin/releases` — lists all stored releases (admin only).
- `DELETE /v1/admin/releases/:id` — manual removal (admin only).

Rationale: Learners need to check and download without signing in. Upload and management are admin-only to prevent unauthorized releases.

### 3. Version comparison using integer version code

Decision: Each release carries a monotonically increasing `version_code` (integer) and a human-readable `version_name` (e.g., `1.2.3`). The mobile app compares its compiled-in `version_code` against the latest backend `version_code` to decide whether an update is available.

Rationale: Integer comparison is unambiguous. Flutter provides `packageInfo.buildNumber` as the version code at runtime.

### 4. Retention: keep only 5 latest per platform

Decision: After a successful upload, the backend checks total release count for that platform. If > 5, it deletes the oldest releases (metadata + file) until exactly 5 remain.

Rationale: Bounded storage with no manual intervention. Five versions give enough rollback runway for the operator without unbounded growth.

### 5. Mobile download + install via content URI

Decision: The app downloads the APK to a temporary file, then uses Android's `ACTION_INSTALL_PACKAGE` intent (via `open_filex` or direct platform channel) to hand off to the system installer. The app requests `REQUEST_INSTALL_PACKAGES` permission in the manifest.

Rationale: Standard Android side-loading flow. No root or device-owner privileges needed. The user sees the normal system install confirmation dialog.

Alternative considered: Use `android.app.DownloadManager` for background download. Rejected for V1 because it adds complexity; a simple foreground HTTP download with progress indicator is sufficient for 15-30 MB APKs on Wi-Fi/LTE.

## Risks / Trade-offs

- [Risk] APK download over mobile data may be expensive for some users -> Mitigation: show file size before download; consider a "Wi-Fi only" preference later.
- [Risk] `REQUEST_INSTALL_PACKAGES` permission may require Play Store policy compliance -> Mitigation: we distribute outside Play; if we ever return to Play, gate the feature behind a flag.
- [Risk] Concurrent uploads could race on the prune step -> Mitigation: serialize upload handling (single admin user in practice); add a simple file lock if needed later.
- [Risk] Large APK serving may spike backend memory -> Mitigation: stream the file from disk using Node.js `createReadStream` instead of buffering the entire file.

## Migration Plan

1. Add `release_versions` table via a new numbered migration (Postgres path) and a `ReleaseStore` class (in-memory + file-based for no-DB path).
2. Add backend routes under `/v1/admin/releases` and `/v1/releases`.
3. Update `contracts/api.md` with new endpoints.
4. Add mobile `UpgradeCheckScreen` accessible from the drawer.
5. Add `REQUEST_INSTALL_PACKAGES` to `AndroidManifest.xml`.
6. After deploy, upload the current production APK as the first release via the admin API.

Rollback: Remove the mobile screen and revert the backend routes. Existing APK files on disk can be manually cleaned.

## Open Questions

- Should the download progress be shown inline on the upgrade screen, or as a system notification?
- Should the version check happen automatically on app launch (with a "new version available" banner), or only when the user explicitly taps "Check for updates"?
- Do we need a `release_notes` field in the metadata for display in the upgrade screen?
