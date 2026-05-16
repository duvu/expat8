Latest deploy: tag 20260510.2150 (exam feature release).

- expat8-backend: <YOUR_REGISTRY>/expat8-backend:20260510.2150 — healthy at http://<INTERNAL_HOST>:18787/health → {"ok":true}
- expat8-dashboard: <YOUR_REGISTRY>/expat8-dashboard:20260510.2150 — healthy at http://<INTERNAL_HOST>:3019/ → HTTP 200. Dashboard image now pushed to registry (was local-only before; changed to registry image in this deploy).
- expat8-worker: same backend image (20260510.2150)
- Exam DB migration (20260511_exam_tables.sql) run manually on production DB: 4 tables + 3 indexes created (exam_sessions, exam_questions, exam_attempts, exam_certificates).
- SSH path: ssh -i /home/beou/deployment/worker-z440/ssh/id_ed25519 -o IdentitiesOnly=yes -o BatchMode=yes beou@<INTERNAL_HOST>
- Deploy command on Z440: cd /home/beou/deployment/worker-z440 && git pull && docker compose pull expat8-backend expat8-dashboard expat8-worker && docker compose up -d --force-recreate expat8-backend expat8-dashboard expat8-worker
- Mobile release APK: built at mobile/build/app/outputs/flutter-apk/app-release.apk (60.7MB), installed on emulator-5554, app runs cleanly. Build cmd: JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 ~/snap/flutter/common/flutter/bin/flutter build apk --release --dart-define=BACKEND_BASE_URL=<YOUR_BACKEND_URL> --dart-define=NEW_WORD_TIMEOUT_SECONDS=5 --dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app --dart-define=APP_CREDENTIAL_SECRET=<YOUR_APP_SECRET> --dart-define=APP_LOG_LEVEL=info
