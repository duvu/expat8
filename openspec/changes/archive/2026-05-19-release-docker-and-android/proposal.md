## Why

The codebase-health-cleanup change updated backend and dashboard code significantly (route extraction, dev tooling, ESLint/Prettier formatting). New Docker images need to be built and pushed to the registry to reflect these changes in production. Simultaneously, a fresh production Android APK is needed to ship alongside the backend — all `--dart-define` values are compiled in and must be rebuilt against the current production `BACKEND_BASE_URL`.

## What Changes

- Build and push a new `expat8-backend` Docker image with timestamp tag (`YYYYMMDD.HHMM`)
- Build and push a new `expat8-dashboard` Docker image with the same timestamp tag
- Update `~/deployment/worker-z440/docker-compose.yml` with both new image tags
- Redeploy both services on the Z440 production stack
- Verify health of both services after redeploy
- Build a signed production Android APK (`app-release.apk`) and AAB (`app-release.aab`) using current production `--dart-define` values
- Verify APK installs and launches on device/emulator

## Capabilities

### New Capabilities

_(none — this is an operational release, not a feature change)_

### Modified Capabilities

- `backend-container-deployment`: Dashboard image is now built and deployed alongside the backend using the same tag convention
- `expat8-dashboard`: Dashboard service now has its own versioned Docker image in the registry

## Impact

- **Backend**: New image tag deployed to Z440; no schema or API changes
- **Dashboard**: New image tag deployed to Z440; no feature changes
- **Mobile**: Fresh signed APK and AAB output; no API or feature changes
- **Production stack**: Both `expat8-backend` and `expat8-dashboard` services restarted with new images
- **Registry**: Two new image tags pushed (`expat8-backend:YYYYMMDD.HHMM`, `expat8-dashboard:YYYYMMDD.HHMM`)
