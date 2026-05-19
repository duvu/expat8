## Context

The project runs two Docker services (backend + dashboard) on a production Z440 host at `~/deployment/worker-z440/docker-compose.yml`. Images are tagged with `YYYYMMDD.HHMM` timestamps and pushed to `<YOUR_REGISTRY>`. The Android APK is a release build with `--dart-define` values compiled in; `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64` is required. The codebase-health-cleanup change modified backend and dashboard source significantly, making fresh images necessary.

Production host port for backend: `18787`. Dashboard port: `3000`. Registry prefix: `<YOUR_REGISTRY>`.

## Goals / Non-Goals

**Goals:**
- Build and push `expat8-backend` image to registry
- Build and push `expat8-dashboard` image to registry
- Deploy both updated images to Z440 using the worker-z440 compose stack
- Verify both services healthy after deploy
- Build signed release APK and AAB from current source
- Verify APK installs and launches

**Non-Goals:**
- Feature changes to backend, dashboard, or mobile
- Database migrations
- Changing any `--dart-define` compile-time values (use the same production values as previous release)
- Play Store submission (manual step outside this change)

## Decisions

### D1: Shared timestamp tag for both Docker images

Both `expat8-backend` and `expat8-dashboard` receive the same `YYYYMMDD.HHMM` tag computed at build time. This makes the release atomic — the compose file references a single tag and both services move together.

**Alternatives considered:** Independent tags per service — rejected because it adds coordination overhead and the release is always both services together.

### D2: Build order — backend first, then dashboard, then Android

Backend is the dependency for mobile; building it first ensures the production URL hasn't changed. Dashboard is fast (Next.js build). Android APK build is the longest step (~5 min) and runs last so Docker push is not blocked by it.

### D3: Deploy via `~/deployment/worker-z440/docker-compose.yml`, not repo compose

Per project convention, production deploy always uses the worker-z440 stack. The local repo `docker-compose.yml` is for local development only. The deploy compose file must have its `expat8-backend` and `expat8-dashboard` image lines updated before `docker compose up`.

### D4: Android APK targets production backend URL

The APK is built with `BACKEND_BASE_URL` pointing to the production public URL (not LAN IP) so it works on both physical devices and emulators. The same `--dart-define` set is used for the `.aab` bundle.

## Risks / Trade-offs

- **[Risk] Stale production credentials** → The `--dart-define` values (`APP_CREDENTIAL_SECRET`, etc.) must be loaded from the local env/secret store before building. Using stale values produces a broken APK silently.
- **[Risk] Dashboard build fails due to Next.js config** → Mitigation: run `npm run build` locally inside `expat8-dashboard/` before wrapping in Docker to catch issues early.
- **[Risk] Z440 deploy disrupts active users** → Mitigation: backend restart is sub-second; compose `--force-recreate` with Docker's stop-before-start is the standard approach. No rolling deploy needed at this scale.
- **[Trade-off] Both services use the same tag** → A build failure on dashboard means backend image exists in registry but doesn't get deployed yet. Acceptable: the compose file is only updated after both images are pushed successfully.
