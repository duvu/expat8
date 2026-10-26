# Cerebrum

> OpenWolf's learning memory. Updated automatically as the AI learns from interactions.
> Do not edit manually unless correcting an error.
> Last updated: 2026-05-09

## User Preferences
- (2026-10-26) Code must follow SOLID, DRY, KISS, YAGNI: shared helpers instead of per-screen copies, single-responsibility classes, no speculative options/abstractions.
- (2026-10-26) Exactly one app instance: fix it at the launch level (Android `singleTask`), never with fallbacks that open/attach the DB twice. User rejected the ObjectBox attach workaround.
- (2026-10-26) Games must visibly level up: each level upgrades graphics AND music; projectiles get stronger/more brilliant and space more detailed/mysterious as the level rises. A shared game story (chapters) frames all games.

- [2026-09-29] UI direction: simple, easy to understand, easy to read, easy to operate. Prefer visible labelled buttons over hidden gestures, plain-language copy (no technical terms), grouped navigation. Shared `StudyActionBar` in `mobile/lib/src/widgets/`.
<!-- How the user likes things done. Code style, tools, patterns, communication. -->

## Key Learnings
- **Dashboard (2026-10-27)**: one pg pool, exported `getPool()` from `src/lib/db.ts`; analytics and other libs must reuse it, never create their own Pool.
- (2026-10-27) **Dashboard structure**: backend calls go through `backendRequest` (throws) or ops-data `load*` ({data,error}); tables use `components/DataTable`, filters `FilterForm` (class `filter-form`, never `toolbar` — that is the sticky page header), status pills `StatusBadge`. Article job statuses: pending_processing / processed|pending_review / processing_failed|dead_lettered. Backend admin URLs needing signed headers must be proxied (e.g. `/ops/logs/[id]/download`). Docker runs `.next/standalone/server.js` (outputFileTracingRoot = app dir). Dashboard SQL can be validated offline with PGlite + backend/db/schema.sql + migrations.
- (2026-10-26) **Backend store layout**: business rules shared by WordStore (memory) and PostgresWordStore live in `backend/src/domain/*.js` (pure, no storage). Per-domain store methods (exam, games, memorization, shadowing, speaking) live in `backend/src/stores/{memory,postgres}/*.js` as method classes mixed in with `mixinMethods` — they cannot use `#private` members (use module functions taking `store`). PG transactions: `stores/postgres/transaction.js`. New shared rules go in `domain/`, never re-implemented per store. `toApiWord`/`toApiWorkplaceSentence` are in `domain/vocabulary.js`, `toApiSpeakingPrompt` in `domain/speaking.js`.
- (2026-10-26) Known store divergences left as-is: PG `getSpeakingSummary` lacks retry_rate/drill_sessions_completed/first_recording_at; PG `submitExamSession` has no local_attempt_id idempotent retry; PG bridged article/passage words skip difficulty normalization; memory `persistArticleVocabulary` does not clear old vocab (PG does).
- **LocalDatabase layout (2026-10-27)**: domain methods live in `part` files as extensions on LocalDatabase; callers must import `data/local_database.dart` (extension scope). Static fields used from extensions need `LocalDatabase.` prefix.
- **Quiz games (2026-10-27)**: new subject = implement QuizLevel/QuizItem/QuizSource + add QuizSubject/QuizGameKind entries + quizGameInfo case; shared Blaster/Whack/Duel work unchanged. Typographic minus via `formatInt` for both answers and options.
- **UI isolate rule (2026-10-26)**: periodic/bulk ObjectBox work goes through `Store.runAsync` with a static worker (same store attached in a worker isolate, not a second open); log rows are buffered + `putManyAsync`; large HTTP JSON via `Isolate.run`. `dart:ui` Gradient needs explicit stops for 3+ colours (use `evenStops`).
- **Game story (2026-10-26)**: sessions expose `chapter` from their own progress; screens call `GameStoryDriver.reach`; scenery/shots/music come from `GameStory.stage(theme, chapter)`. Chapter 5 is the cap.
- **Math games (2026-10-26)**: 5 kid math games live in `lib/src/games/math/`, built on plain Flutter + `MathLoop` (Ticker), not Flame. Share `MathProblemGenerator` (adaptive, Grade 1-5), `MathSkillTracker` (missed facts replay), `MathRoundLog`, home/result screens and `GameVisualTheme` skins. Only the moving layer listens to a per-frame `ValueNotifier`; setState only on visible changes. `WordRepository(shuffleNewWords: false)` gives deterministic new-word order for tests of non-selection flows.
- **Game perf (2026-10-26)**: never call `FlameAudio.play` for frequent SFX (spawns a native player per call -> jank after minutes); use `GameAudio` pools. Sessions driving widgets must notify only on UI-visible change, not every frame. In Flame `render`, don't allocate Paint/Shader/TextPainter per frame: record static art into a `Picture`, reuse Paints, dispose painters/pictures in `onRemove`.

- **Engagement (2026-10-27)**: streak/goal/due-soon are computed locally in `mobile/lib/src/engagement/` from StudyEventEntity.ownerUserId-scoped events; settings key `engagement.settings.<userId|anonymous>`. Reminders = up to 7 one-shot inexact notifications at UTC instants (no tz database), rebuilt on every stats refresh. flutter_local_notifications 22 needs `isCoreLibraryDesugaringEnabled` + desugar_jdk_libs in android/app/build.gradle.kts.

- **flutter_test draws shadows as solid black outlines** (`debugDisableShadows`); set it false (and restore) when judging UI from golden screenshots.

- **Practice games record via `WordRepository.recordPracticeAnswer`** (game source, correct=easy, wrong=hard, scheduled by the shared SRS). (Updated 2026-10-27: the card-flow `easy` path no longer deletes words.)
- **Flame widget tests**: tap by canvas coordinates, advance with timed `pump`, never `pumpAndSettle` while a game loop runs; widget-test HTTP returns 400 for every request, so fake offline APIs must throw instead.

- **Production backend sits behind a reverse proxy** (expat8.x51.vn → Z440 port 18787); IP-based limits need `TRUST_PROXY` set to the proxy address. Z440 Caddyfile does not route expat8 — the proxy is upstream/elsewhere.
- **Auth rate limiting:** `authIpLimiter` (per IP, shared) runs before per `ip|identifier` limiters in `routes/auth.js`.

- **Root `openspec/` is gitignored and absent locally**; only `backend/openspec/changes/` is tracked. Roadmap references to `openspec/changes/*` cannot be verified from the repo.
- **Dashboard reads PostgreSQL directly** (`expat8-dashboard/src/lib/db.ts`, `analytics.ts`) in addition to signed backend API calls.

- **Project:** expat8
- **Description:** This workspace contains the OpenSpec-driven MVP implementation for a Flutter vocabulary learning app and a lightweight backend service.
- **Repo guidance:** `backend/` is Node.js 22 + Express, `mobile/` is Flutter, `contracts/api.md` is the API source of truth, and `docker-compose.yml` starts PostgreSQL + backend locally.
- **Host mapping:** `<INTERNAL_HOST>` is the local machine for this workspace, so deploy commands targeting that IP are effectively local-host operations here.

- (2026-10-25) Prod expat8 = ONE container `expat8-backend` on z440 with `EMBEDDED_WORKER=true` (no separate worker service; user's explicit choice). DB via direct 5432, not pgbouncer. See memory note expat8-production-layout.
- (2026-10-25) Mobile release build needs JDK 17 (`/usr/lib/jvm/java-17-openjdk-amd64`); java-21 there is a JRE without javac.

- (2026-10-27) **SRS is shared JS/Dart**: `backend/src/domain/srs.js` and `mobile/lib/src/srs/srs_scheduler.dart` must stay identical; regenerate `contracts/srs_vectors.json` from the JS reference and run both test suites when changing it. Server state = replay of ALL the owner's events for a word (never "last event wins"); `npm run rebuild:srs` after scheduler changes.
- (2026-10-27) **Mobile schedule invariants**: `upsertWord` keeps an existing word's status/nextReview/SRS memory (refetched due cards must not reset progress); study events carry local-only `ownerUserId` (queue payload `owner_user_id`, stripped before upload); account switch → `rebuildScheduleForOwner`; `pullReviewStates` skips words with pending events.
- (2026-10-27) **Route `?limit=`**: use `queryLimit(raw, fallback, max)` from routes/helpers.js — the old `clampLimit(raw, min, max)` returned 1 when the param was missing (app saw 1 article). `domain/pagination.js#clampLimit` is a different, store-level helper.
- (2026-10-27) **Ladder window**: "6 too_hard in last 10" counts events that OCCURRED after `user_proficiency.level_changed_at`; arrival time is useless because one offline sync delivers a batch in the same millisecond.
- (2026-10-27) **Never pick random UI variants inside build()** (old `shouldShowFitb` re-rolled on every rebuild); decide once when the card is selected (`currentExercise`).

## User Preferences

- [2026-09-28] User removed PR CI (GitHub Actions checks too slow). Do not re-add CI workflows; run checks locally. Keep android-release.yml (signing secrets).
- User writes in Vietnamese (no diacritics); reply and write review docs in Vietnamese.
- Goal (2026-09-28): production-grade, high-quality product.
- Keep root repo instructions compact and only include high-signal, repo-specific facts.

## Do-Not-Repeat
- (2026-09-29) VPS 10.113.213.1: never disable RabbitMQ management plugin/port 15672 on openstock-rabbitmq -- OpenStock platform-health check depends on the management API. Queues live in vhost `/openstock` (rabbitmqctl list_queues without `-p /openstock` shows 0).
- (2026-09-29) Never run `pkill -f <pattern>` inside an `ssh host '...'` command string: the remote bash command line contains the pattern and kills its own session. Use `pgrep -f "[x]yz"` bracket trick + xargs kill.

- [2026-09-28] Flutter 3.47.5 needs Gradle ≥ 8.14, AGP ≥ 8.11.1, Kotlin ≥ 2.2.20; objectbox_flutter_libs declares compileSdk 31 → root build.gradle.kts raises library plugins to 36. CI was removed on 2026-09-28 (user: checks too slow), so a failing Android build only shows up in the tag-triggered release workflow.
- [2026-09-28] Release signing secrets exist only in GitHub Actions; build releases by pushing tag `v<pubspec version>` (Android Release workflow), not locally.

<!-- Mistakes made and corrected. Each entry prevents the same mistake recurring. -->
<!-- Format: [YYYY-MM-DD] Description of what went wrong and what to do instead. -->
- [2026-10-26] Backend PG tests: run `TEST_DATABASE_URL=... node --test --test-concurrency=1`; with the default parallel `npm test` 4 PG tests fail because test files share one database. A throwaway DB: `docker run -d --rm -e POSTGRES_PASSWORD=test -e POSTGRES_DB=expat8_test -p 127.0.0.1:55439:5432 postgres:18.4-bookworm` (image is cached locally).
- [2026-09-28] `crypto.promises` does not exist in Node — use `util.promisify(crypto.scrypt)` for async scrypt.
- [2026-09-28] `flutter test` on the local Flutter 3.47.5 rewrites `mobile/pubspec.lock` and `analysis_options.yaml`; revert them after running if not intended. Flutter version is not pinned.

- (2026-10-27) Do not `git rm --cached` (or touch the index) while cleaning files — nothing is committed in this repo unless the user asks; delete with `rm` only.
- (2026-10-27) Before putting an admin web app on any host, check it has its own auth; the expat8 dashboard has none → VPN-only (10.113.213.9:18788).

## Decision Log

<!-- Significant technical decisions with rationale. Why X was chosen over Y. -->
- 2026-09-29: Form screens with validators should use SingleChildScrollView+Column, not ListView — lazy ListView doesn't build off-screen fields (tests couldn't find submit button; validators skip unbuilt fields).
- 2026-09-29: Don't `git checkout main` with uncommitted version bump — commit on the release branch first (use `git commit -- <path>`, not `-am -- path`).
- 2026-09-29: Prod DB goes through pgbouncer (transaction mode, shared with other projects); migrations use session pg_advisory_lock → run `npm run migrate` with DATABASE_URL pointing directly at `postgres:5432`.
- 2026-09-29: App-credential failures return 400 (not 401) and mobile treats 400/404 as permanent → drops queued sync events. Deploy backend before app releases.
- 2026-09-29: Credential lookup is by appId (one secret per appId) → rotation needs a new appId. Request logs have no app_id field.
- 2026-09-29: In-app update: banner uses GitHub releases/latest; "Check for updates" uses backend /v1/releases/latest → every release needs `scripts/admin-request.mjs POST /v1/admin/releases`.
- 2026-09-29: ~/deployment/worker-z440 on this dev machine (MyBuntu) is a config copy; Z440 is a different host — never operate prod from here without the user.
- 2026-09-29: Dashboard has no auth (internal port 3019 only).
- (2026-09-29) LLM gateway for expat8 is OmniRoute (omni.x51.vn / VPN 10.113.213.1:20128, OpenAI-compatible). Old LiteLLM :5003 is gone. Z440 compose reads EXPAT8_LITELLM_BASE_URL/_API_KEY/_MODEL (default model `editor8-gpt` does not exist in OmniRoute). Test gotcha: AbortSignal.timeout timers are unref'd — node:test cancels the test unless a ref'd timer keeps the loop alive.
- (2026-09-29) OmniRoute free no-auth providers are unusable for expat8 from the DO VPS: opencode 403 (free tier only inside OpenCode), duckduckgo 418 IP rate-limit, felo 400, chipotle 404, uncloseai upstream 502, cloudflare-playground/theoldllm need Playwright+Chromium (theoldllm also blocks datacenter IPs), aihorde works but caps output ~20-70 tokens. Needs a real API-key provider. Free providers are added via POST /api/providers/free-onboarding {confirmed:true, providerIds:[...]} with a manage-scope key.
- (2026-09-29) expat8 LLM = OmniRoute combo `expat8` (priority: cx/gpt-5.6-terra-low → cx/gpt-5.6-luna-low, ChatGPT-account Codex OAuth). ~2.5s per generated word → keep VOCAB_GENERATION_BATCH_SIZE ≈20 under LITELLM_TIMEOUT_MS 120s. gpt-5.3-codex-spark is NOT allowed on ChatGPT-account Codex. Combos created via POST /api/combos {name, strategy, models:[...]}.
- (2026-09-29) OmniRoute 3.8.50 gotcha: round-robin (sticky 1) and least-used always pick the SAME account because account selection runs several times per request and each run commits lastUsedAt. Use providerStrategies.codex = {fallbackStrategy:"random"} (PATCH /api/settings) for multi-account load balance; verified split via call_logs.connection_id.
- (2026-09-29) OmniRoute load balancing: combo round-robin is defeated by prompt-cache affinity (settings.promptCacheAffinityEnabled, default on) — it rendezvous-hashes the system-prompt prefix and forces rrStartIndex=0, so identical system prompts (all expat8 vocab calls) always hit one target. Disabled globally. Also set combo config disableSessionStickiness=true, stickyRoundRobinLimit=1, concurrencyPerModel=2. Verify spread with call_logs.provider.
- (2026-09-29) OmniRoute provider status for expat8: working = codex x2, kiro, antigravity, github (only gpt-5.4-nano/gpt-4o/gpt-4.1; gpt-5-mini & claude-haiku "not supported"), gemini apikey (gemini-3-flash-preview / 3.1-flash-lite; 2.5-flash retired). Broken = kimi-coding (banned upstream), kilocode (401 sign in; openrouter/free ~120s), opencode apikey (402 "requires key" — key not applied), amazon-q (400 malformed).

- (2026-10-25) Logger meta fields must never be named `level` (overrides log level); use `cefr_level`.
- (2026-10-25) All LLM calls go through the shared `LlmRateLimiter` (`getSharedLlmRateLimiter`, env `LLM_*`): 3s spacing, concurrency 1, 120 req/h, 429/Retry-After backoff. Scheduler/crawler pause when remaining hourly budget <= `LLM_RESERVED_REQUESTS_PER_HOUR`. New background LLM features must take the limiter, not call fetch directly.
- (2026-10-25) Word pool: scheduler fills per-level targets (`VOCAB_LEVEL_TARGETS`), `learningCards` ranks by user level (`selectNewCardsByLevel`). Crawler (`content_crawler.js`, every `CRAWLER_INTERVAL_MINUTES`) -> RSS -> LLM `assessArticle` (level/quality/suitable) -> ownerless article -> article pipeline auto-approves into `words`/`workplace_sentences`. URLs remembered in `crawled_urls`.
- (2026-10-25) Prod deploy: `docker build` -> `docker save | ssh 10.113.213.9 docker load` -> edit EXPAT8_BACKEND_IMAGE in ~/deployment/worker-z440/.env -> `docker compose run --rm --no-deps expat8-backend npm run migrate` -> `up -d --force-recreate expat8-backend`. DB query helper: `docker exec expat8-backend node -e` with `pg`.
- (2026-10-25) OmniRoute combo `expat8` can be fully down (codex quota "reset after 541h", kiro needs profileArn, gemini circuit open) -> every call 502. `LlmRateLimiter` has a circuit breaker (`LlmUnavailableError`): workers skip all LLM steps while open and LLM outages never consume article/submitted-word retry attempts. Check with a direct curl to http://10.113.213.1:20128/v1/chat/completions before debugging code.
- (2026-10-25) Curated reading collection (`curated_collector.js`, topics in `curated_topics.js`): Wikipedia/Simple Wikipedia extracts, 20 backfill (1 per 15 min) then 1 per `CURATED_INTERVAL_DAYS`; progress derived from `crawled_urls` rows with feed_url `curated:*`. Article jobs stuck in `processing` are reclaimed after 15 min (`STALE_ARTICLE_JOB_MS`).
- (2026-10-27) Family devices: per-account schedules via event owner stamping + local replay + server pull, instead of a per-owner local entity (no ObjectBox refactor).
- (2026-10-27) Review cards are active-recall exercises; grading never yields `too_easy` (would move the CEFR level up); wrong answers (`too_hard`) feed the downgrade rule the user asked for ("hạ cấp nếu trả lời sai nhiều từ").
