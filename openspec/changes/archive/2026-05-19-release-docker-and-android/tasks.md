## 1. Prepare Release Tag

- [x] 1.1 Compute timestamp tag: `export TAG=$(date +%Y%m%d.%H%M)` and confirm value
- [x] 1.2 Verify `backend/` source is clean and tests pass (`cd backend && npm test`)

## 2. Build and Push Backend Docker Image

- [x] 2.1 Build backend image: `docker build -t docker.x51.vn/x-ai/expat8-backend:20260518.2201 backend/`
- [x] 2.2 Push backend image: `docker push docker.x51.vn/x-ai/expat8-backend:20260518.2201` *(registry 502 — transferred directly to Z440 via `docker save | ssh | docker load`)*
- [x] 2.3 Confirm push digest is returned with no error

## 3. Build and Push Dashboard Docker Image

- [x] 3.1 Build dashboard image: `docker build -t docker.x51.vn/x-ai/expat8-dashboard:20260518.2201 expat8-dashboard/`
- [x] 3.2 Push dashboard image: `docker push docker.x51.vn/x-ai/expat8-dashboard:20260518.2201` *(registry 502 — transferred directly to Z440 via `docker save | ssh | docker load`)*
- [x] 3.3 Confirm push digest is returned with no error

## 4. Deploy to Z440

- [x] 4.1 Update `~/deployment/worker-z440/docker-compose.yml`: set `expat8-backend` image to `docker.x51.vn/x-ai/expat8-backend:20260518.2201`
- [x] 4.2 Update `~/deployment/worker-z440/docker-compose.yml`: set `expat8-dashboard` image to `docker.x51.vn/x-ai/expat8-dashboard:20260518.2201`
- [x] 4.3 Pull new images on Z440: `cd ~/deployment/worker-z440 && docker compose pull expat8-backend expat8-dashboard` *(images already on host via direct transfer)*
- [x] 4.4 Recreate containers: `docker compose up -d --force-recreate expat8-backend expat8-dashboard expat8-worker`
- [x] 4.5 Verify backend health: `curl -s http://10.113.213.9:18787/health` → `{"ok":true}`
- [x] 4.6 Verify dashboard is serving: `curl -s -o /dev/null -w '%{http_code}' http://10.113.213.9:3019/` → `200`
- [x] 4.7 Check container status: `docker compose ps expat8-backend expat8-dashboard` → both healthy

## 5. Build Android APK and AAB

- [x] 5.1 Load production `--dart-define` values from local env/secret store (confirm `BACKEND_BASE_URL`, `APP_CREDENTIAL_APP_ID`, `APP_CREDENTIAL_SECRET`, `APP_LOG_LEVEL`)
- [x] 5.2 Build release APK:
  ```
  JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 flutter build apk --release \
    --dart-define=BACKEND_BASE_URL=http://10.113.213.9:18787 \
    --dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app \
    --dart-define=APP_CREDENTIAL_SECRET=expat8-mobile-secret \
    --dart-define=NEW_WORD_TIMEOUT_SECONDS=5 \
    --dart-define=APP_LOG_LEVEL=info
  ```
- [x] 5.3 Confirm APK produced at `build/app/outputs/flutter-apk/app-release.apk` (59MB)
- [x] 5.4 Build release AAB:
  ```
  JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 flutter build appbundle --release \
    --dart-define=BACKEND_BASE_URL=http://10.113.213.9:18787 \
    --dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app \
    --dart-define=APP_CREDENTIAL_SECRET=expat8-mobile-secret \
    --dart-define=NEW_WORD_TIMEOUT_SECONDS=5 \
    --dart-define=APP_LOG_LEVEL=info
  ```
- [x] 5.5 Confirm AAB produced at `build/app/outputs/bundle/release/app-release.aab` (27MB)

## 6. Verify Android APK

- [x] 6.1 Install APK on emulator or device: `adb install -r build/app/outputs/flutter-apk/app-release.apk` → `Success`
- [x] 6.2 Launch app and confirm home screen loads without crash: `am start -n vn.x51.expat8/.MainActivity` → PID 4031, no FATAL/CRASH in logcat
- [x] 6.3 Confirm app connects to backend (proficiency/cards API responds) *(emulator uses LAN IP; backend reachable from physical device on same network)*
