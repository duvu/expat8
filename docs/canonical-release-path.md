# Canonical Release and Update Path

> **Status:** Decided — May 2026. Supersedes any conflicting guidance in individual OpenSpec changes.

This document defines the canonical three-stage model for mobile release distribution and in-app update discovery for the next 12 months. Any OpenSpec change touching releases must reference this document and state which stage it affects.

## Three-Stage Model

### Stage 1 — GitHub Releases (Audit Trail)

- Every published APK or AAB artifact is uploaded to GitHub Releases with a version tag (`v<semver>`).
- GitHub Releases is the **source of record** for release artifacts and release notes.
- GitHub Releases is **not** queried by the mobile app at runtime.
- The `mobile-github-releases` change implements CI release workflow and artifact upload.

### Stage 2 — Backend-Hosted Release Metadata (Runtime Update Discovery)

- The mobile app checks for available updates by querying `GET /v1/releases/latest?platform=android` on the backend.
- The backend release metadata is updated whenever a new release is published (upload APK to `POST /v1/admin/releases`).
- This provides a controlled, app-credential-signed update check that does not depend on GitHub API availability.
- The `mobile-self-upgrade` change implements this flow end-to-end (backend store, routes, mobile upgrade check screen).

> **Current state (2026-09-29):** both update paths ship in the app. The update *banner* (`update/update_banner.dart` → `github_release_service.dart`) queries the GitHub API; the *Check for updates* screen (`ui/upgrade_check_screen.dart`) uses the backend endpoint and downloads the APK from the backend. Every release therefore needs both the GitHub Release (automatic) and the backend upload (manual, [ops/mobile-release.md](ops/mobile-release.md#4-đưa-apk-lên-backend-cập-nhật-trong-app)); `scripts/ops-check.mjs` flags a mismatch. Moving the banner to the backend endpoint remains the intended end state.

### Stage 3 — Play Store (Deferred Public Distribution)

- Play Store submission is **deferred** until the following preconditions are met:
  1. Release signing procedure is documented and verified end-to-end.
  2. Staged rollout expectations are defined.
  3. Rollback procedure (side-load fallback) is documented.
- No OpenSpec change should target Play Store listing without first confirming these preconditions and referencing this document.

## Active Release Changes and Status

| Change | Stage | Status |
|---|---|---|
| `fix-build-release-consistency` | Stage 1 (release workflow, APK+AAB artifacts) | All tasks complete ✅ |
| `mobile-github-releases` | Stage 1 (release workflow, artifact upload) + in-app banner (interim) | Complete ✅ — verified end-to-end on v1.3.3 and v1.3.4 |
| `mobile-self-upgrade` | Stage 2 (backend metadata, mobile upgrade screen) | All tasks complete ✅ |

Only the tag-triggered `Android Release` workflow remains in GitHub Actions; pull-request CI was removed (2026-09-28, #38) and checks run locally ([testing-guide.md](testing-guide.md)).

## Verification Requirements

Each release must:
1. Upload APK/AAB to GitHub Releases (Stage 1) — done by the `Android Release` workflow.
2. Update backend release metadata via `POST /v1/admin/releases` (Stage 2) — `node scripts/admin-request.mjs POST /v1/admin/releases --file app-release.apk ...`.
3. Confirm mobile app update check discovers new version via `GET /v1/releases/latest` — `node scripts/ops-check.mjs`.

Step-by-step runbook: [ops/mobile-release.md](ops/mobile-release.md).

## Related Files

- `docs/20260530-project-roadmap-12-month.md` — Phase 0 gate: canonical release path
- `openspec/changes/mobile-self-upgrade/` — Stage 2 implementation
- `openspec/changes/mobile-github-releases/` — Stage 1 implementation
- `openspec/changes/fix-build-release-consistency/` — CI release workflow
