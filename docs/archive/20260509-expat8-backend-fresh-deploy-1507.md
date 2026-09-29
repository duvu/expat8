# Deploy Report: expat8-backend Fresh Deploy

**Date:** 2026-05-09
**Tag:** `20260509.1507`
**Image:** `<YOUR_REGISTRY>/expat8-backend:20260509.1507`
**Server:** `<INTERNAL_HOST>`

## Summary

| Step | Status | Notes |
|------|--------|-------|
| Backend tests | Passed | `cd backend && npm test` |
| Docker build | Passed | Built fresh with `--no-cache` |
| Docker push | Passed | Registry digest `sha256:4a582d43ff6e30e0384a7696d023403a82347300a3c9dd813d5c256482733aaa` |
| Deployment update | Passed | Updated `/home/beou/deployment/worker-z440/docker-compose.yml` default image tag |
| Container recreate | Passed | `docker compose up -d --force-recreate expat8-backend` |
| Smoke test | Passed | `GET http://<INTERNAL_HOST>:18787/health` returned `{"ok":true}` |
| Android release APK | Passed | Built `mobile/build/app/outputs/flutter-apk/app-release.apk` with backend URL `http://<INTERNAL_HOST>:18787` |

## Issues Encountered & Fixes Applied

- Android build initially failed because Gradle used Java 8. Retried the build with `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64`; APK build passed.

## Verification

```text
docker inspect expat8-backend -> <YOUR_REGISTRY>/expat8-backend:20260509.1507 running healthy
curl -fsS http://<INTERNAL_HOST>:18787/health -> {"ok":true}
app-release.apk size -> 25445541 bytes
```
