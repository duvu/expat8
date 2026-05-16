# Copilot Instructions

## Expat8 Backend Deploy Workflow (Z440)

When the user asks to deploy `expat8-backend`, always use this exact sequence:

1. Build image from repository backend source:
   - `docker build -t <YOUR_REGISTRY>/expat8-backend:<TAG> backend`
2. Push image to registry:
   - `docker push <YOUR_REGISTRY>/expat8-backend:<TAG>`
3. Update deploy stack file:
   - `~/deployment/worker-z440/docker-compose.yml`
   - Set `expat8-backend` image to the new tag.
4. Redeploy from deployment directory (not local repo compose):
   - `cd ~/deployment/worker-z440`
   - `docker compose up -d --force-recreate expat8-backend`
5. Verify:
   - `docker compose ps expat8-backend`
   - `curl -i -sS http://<INTERNAL_HOST>:18787/health | head -n 5`

## Important

- Do **not** treat local compose in the source repo as production deploy.
- Do **not** stop after local `expat8-backend-1` is healthy; deployment target is `expat8-backend` in `~/deployment/worker-z440`.
- Prefer timestamp tags in format `YYYYMMDD.HHMM`.

## Flutter Build (expat8 mobile)

`BACKEND_BASE_URL` and other `--dart-define` values are **compiled into the binary** — changing them always requires a full rebuild. Do not attempt to patch or swap values at runtime.

Use the same production `--dart-define` set for both the signed APK and the signed AAB.

### Android Emulator Networking

- Android emulator runs in an isolated virtual network and **cannot reach LAN/VPN IPs** (e.g. `10.x.x.x`).
- Always use `<YOUR_BACKEND_URL>` as `BACKEND_BASE_URL` when building for the emulator.
- LAN IPs (e.g. `<INTERNAL_HOST>:18787`) only work on **physical devices** connected to the same network.

### Standard build commands

```bash
# For emulator / public access
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 ~/snap/flutter/common/flutter/bin/flutter build apk --release \
  --dart-define=BACKEND_BASE_URL=<YOUR_BACKEND_URL> \
  --dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app \
  --dart-define=APP_CREDENTIAL_SECRET=<YOUR_APP_SECRET> \
  --dart-define=APP_LOG_LEVEL=info

# Production bundle
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 ~/snap/flutter/common/flutter/bin/flutter build appbundle --release \
  --dart-define=BACKEND_BASE_URL=<YOUR_BACKEND_URL> \
  --dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app \
  --dart-define=APP_CREDENTIAL_SECRET=<YOUR_APP_SECRET> \
  --dart-define=APP_LOG_LEVEL=info

# Install on emulator
~/Android/sdk/platform-tools/adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk
~/Android/sdk/platform-tools/adb -s emulator-5554 shell am start -n vn.x51.expat8/.MainActivity
```
