# Expat8 Language Learning MVP

This workspace contains the OpenSpec-driven MVP implementation for a Flutter vocabulary learning app, an `expat8-dashboard` admin web app, and a lightweight backend service.

## Adaptive Proficiency

The current app/backend flow includes an adaptive CEFR proficiency ladder:

- New devices initialize at `A1`
- Mobile shows the current level in the top-right corner of the learning screen
- Rating buttons are `Easy`, `Too Easy`, `Hard`, and `Too Hard`
- Backend upgrades proficiency after 5 consecutive `too_easy` ratings
- Backend downgrades proficiency after 5 consecutive `hard` ratings
- `/v1/learning/cards` is the single card-loading endpoint and returns
  backend-selected batches using learner state
- The mobile app stores local vocabulary, study events, settings, sync queue
  entries, and logs in ObjectBox.
- Learners can also capture their own unfamiliar words from the mobile app; the
  app queues the submission locally, the backend enriches it asynchronously,
  and the resolved word joins the normal study inventory.
- All mobile `/v1/*` calls are signed with app credential headers; optional
  user sessions ride inside that app-credential layer.

See `contracts/api.md` for the request and response shapes.

## Structure

- `mobile/`: Flutter app source for Android and iOS using ObjectBox local storage.
- `backend/`: Node.js backend service using ExpressJS and `node:test`.
- `expat8-dashboard/`: Next.js admin dashboard for article upload and vocabulary review.
- `contracts/`: mobile-backend API contracts.
- `docs/`: product and technical documentation.
- `openspec/`: change proposal, design, specs, and tasks.

## Local Configuration

Mobile compile-time values:

```bash
flutter run \
	--dart-define=BACKEND_BASE_URL=<YOUR_BACKEND_URL> \
	--dart-define=NEW_WORD_TIMEOUT_SECONDS=5 \
	--dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app \
	--dart-define=APP_CREDENTIAL_SECRET=<YOUR_APP_SECRET>
```

Android release builds use the same production `--dart-define` values for both the signed APK and the signed bundle. Keep these values in your local environment or secret store and inject them at build time; do not hardcode them in GitHub-tracked files:

```bash
cd mobile
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64 flutter build apk --release \
  --dart-define=BACKEND_BASE_URL=https://expat8.x51.vn \
  --dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app \
  --dart-define=APP_CREDENTIAL_SECRET=<YOUR_APP_SECRET> \
  --dart-define=NEW_WORD_TIMEOUT_SECONDS=5 \
  --dart-define=APP_LOG_LEVEL=info
```

The APK lands at `build/app/outputs/flutter-apk/app-release.apk`; `flutter build appbundle --release` with the same values still produces `build/app/outputs/bundle/release/app-release.aab`. If any of the build-time values change, rebuild the package so the binary picks up the new config.

Use a local env file or secret manager for these values. Do not commit production `--dart-define` values into GitHub-tracked files.
When building packages for deploy, always source the current values first, then rebuild the APK/AAB. Do not reuse stale compiled values after updating the backend URL, app credential id/secret, or app log settings.

Mobile card loading uses `POST /v1/learning/cards` with `card_mode: "new"`.
The backend owns duplicate avoidance through learner state and
`PUT /v1/user-word-cache`; mobile no longer sends exclusion lists for card
refill.
User-entered words are submitted through `POST /v1/user-submitted-words` and
polled through `GET /v1/user-submitted-words`, with status values
`queued`/`processing`/`ready`/`failed` documented in `contracts/api.md`.

Backend environment:

```bash
cd backend
copy .env.example .env
npm test
npm start
```

The backend requires signed app credential headers for `/v1/*` requests.
`GET /health` remains unsigned for health checks. See `contracts/api.md` and
`docs/app-credential-security.md` for the signing contract.

The backend test suite now covers adaptive proficiency state, learning-card
selection, single-event submission, and sync responses:

```bash
cd backend
npm test
```

Docker Compose backend stack:

```bash
LITELLM_API_KEY=your-key docker compose up --build -d
curl http://localhost:8787/health
docker compose logs -f backend
docker compose down
```

The Compose stack builds the ExpressJS backend image, starts PostgreSQL,
initializes the database from `backend/db/schema.sql`, and exposes the backend
on `http://localhost:${BACKEND_PORT:-8787}`. The `expat8-dashboard` service is
already wired in `docker-compose.yml`. LiteLLM is optional for local smoke
tests. Without a reachable LiteLLM server or API key, the backend falls back to
stored words and rejects failed generation attempts without exposing sensitive
data.

## Roadmap

### v1 — Internal Milestone (current)

The v1 milestone covers the full offline-first vocabulary learning loop, speaking foundation (local drill only), and vocabulary exam.

**Shipped**

| Feature | Notes |
|---|---|
| Vocabulary flashcard (SRS) | Swipe + FITB card modes; local-first from ObjectBox |
| Adaptive CEFR proficiency | English A1→C2; auto-upgrade/downgrade from rating history |
| Adaptive HSK proficiency | Chinese HSK1→HSK6; same mechanics |
| User accounts | Register, sign-in, sign-out, anonymous fallback via `device_id` |
| Study event sync | Single and batch; offline queue with retry |
| User-submitted vocabulary | Learner types a word; mobile queues it locally; backend AI enriches it asynchronously |
| Article-based vocabulary | LLM enrichment pipeline; admin publish flow |
| Speaking foundation | Local record + playback + self-rate drill; behavioral event sync (no audio upload) |
| Weekly speaking summary | `GET /v1/speaking/summary` |
| Vocabulary exam | Language-scoped MCQ; auto-advance on tap; results + shareable certificate |
| Admin dashboard | Article management, vocabulary review, speaking prompt review |
| App credential security | HMAC signing on all `/v1/*` requests; nonce replay protection |

**Code complete — pending device verification**

| Change | Status |
|---|---|
| Exam auto-advance flow | Code done; manual device test outstanding |
| Exam results screen fix | Code done; manual device test outstanding |
| Certificate screen API client fix | Code done; manual device test outstanding |
| Swipe local prefetch + smart prune | Code done; manual device test outstanding |

### Beyond v1

| Phase | Target | Key capability |
|---|---|---|
| v1.1 | Near-term | AI pronunciation feedback (server-side audio analysis) |
| v1.2 | 3-6 months | Personalized speaking path by goal, CEFR, weak sounds |
| v2 | 6-12 months | AI conversational role-play coach |
| v3 | 12-24 months | Paid plans, human feedback, community speaking |

See `docs/20260509-expat8-product-roadmap-2026-2028.md` for the full 2-year vision.
