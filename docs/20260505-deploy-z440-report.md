# Deploy Report: expat8 -> Z440

> Historical note (2026-05-06): this deployment report records one dated
> deployment. Build warnings or storage-route details here are not current
> setup guidance.

**Date:** 2026-05-05 06:04 Asia/Ho_Chi_Minh  
**Tag:** 20260505.0604  
**Server:** 10.113.213.9  

## Summary

| Step | Status | Notes |
|------|--------|-------|
| Project validation | Partial | Project exists and backend Dockerfile builds. Local `docker-compose.yml` does not define a registry `image:` for `backend`, so direct Docker build was used. |
| Docker build & push | Pass | Built and pushed `docker.x51.vn/x-ai/expat8-backend:20260505.0604`. |
| DB migration | Pass | Applied adaptive proficiency dependency and identity migration on production DB. |
| Deployment update | Partial | Local deployment compose updated and committed. `git push` to GitHub timed out over SSH. |
| Container recreate | Pass | Recreated `expat8-backend` on Z440 with image tag `20260505.0604`. |
| Smoke test | Pass | Health endpoint and signed register/sign-in/sign-out flow passed. |
| Regression test | Pass | Backend tests pass locally; Flutter analyze passes; Android APK builds. |

## Artifacts

- Backend image: `docker.x51.vn/x-ai/expat8-backend:20260505.0604`
- Backend image digest: `sha256:c543f5833d53f6779685b814b55d2804beb06772566f43c47ce25c9a6d685fd6`
- Android APK: `mobile/build/app/outputs/flutter-apk/app-release.apk`
- Android APK SHA-256: `6e7f277e469d42d8b85fb5fedc8ac8552b1791ffa0db8db49c10b83567a62d17`

## Issues Encountered & Fixes Applied

- Android build initially used Java 8 and failed because the Android Gradle plugin requires Java 11+. Re-ran the build with `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64`.
- Android build warned that `sqflite_android` prefers Android NDK `27.0.12077973` while the project is configured with Flutter's default NDK. Build still completed.
- Initial identity migration failed because `user_proficiency` did not exist yet.
  Applied `backend/db/migrations/20260504_add_adaptive_proficiency_system.sql`
  first, then reran identity migration.
- Identity migration as DB user `expat8` failed while creating an index on
  `study_events` because that table is owned by `postgres`. Reran the identity
  migration inside `postgres-z440` as role `postgres`.
- `git push` from `/home/beou/deployment` to `git@github.com:x51vn/deployment.git`
  timed out over SSH. The local deployment commit is present but not pushed.
- `/home/beou/deployment` had pre-existing unrelated staged deletions under `worker-z440/images/*` and a modified `.gitignore`; these were not touched.

## Test Results

```text
npm test
tests 43, pass 41, skipped 2, fail 0
```

```text
flutter analyze
No issues found
```

```text
flutter build apk --release
Built build/app/outputs/flutter-apk/app-release.apk (21.3MB)
```

```text
curl http://10.113.213.9:18787/health
HTTP/1.1 200 OK
{"ok":true}
```

```text
signed register/sign-in/sign-out smoke
registered=true
signedIn=true
signedOut=true
```

```text
docker ps
expat8-backend docker.x51.vn/x-ai/expat8-backend:20260505.0604 healthy
```

## Remaining Follow-up

Push the local deployment repo commit when GitHub SSH connectivity is available:

```bash
cd /home/beou/deployment
git push
```

Local commit:

```text
11d3df1 deploy(expat8): update backend image to 20260505.0604
```
