# anatomy.md

> Auto-maintained by OpenWolf. Last scanned: 2026-05-30T10:27:10.221Z
> Files: 573 tracked | Anatomy hits: 0 | Misses: 0

## ./

- `.gitignore` — Git ignore rules (~27 tok)
- `AGENTS.md` — AGENTS.md (~513 tok)
- `CLAUDE.md` — OpenWolf (~1609 tok)
- `docker-compose.yml` — Docker Compose services (~986 tok)
- `expat8.code-workspace` (~44 tok)
- `README.md` — Project documentation (~2014 tok)

## .claude/

- `settings.json` (~441 tok)
- `settings.local.json` (~380 tok)

## .claude/commands/opsx/

- `apply.md` — Implementing: <change-name> (schema: <schema-name>) (~1146 tok)
- `archive.md` — Archive Complete (~1254 tok)
- `explore.md` — The Stance (~1586 tok)
- `propose.md` (~1104 tok)

## .claude/rules/

- `openwolf.md` (~313 tok)

## .claude/skills/openspec-apply-change/

- `SKILL.md` — Implementing: <change-name> (schema: <schema-name>) (~1190 tok)

## .claude/skills/openspec-archive-change/

- `SKILL.md` — Archive Complete (~1039 tok)

## .claude/skills/openspec-explore/

- `SKILL.md` — The Stance (~2309 tok)

## .claude/skills/openspec-propose/

- `SKILL.md` (~1161 tok)

## .codex/skills/openspec-apply-change/

- `SKILL.md` — Implementing: <change-name> (schema: <schema-name>) (~1190 tok)

## .codex/skills/openspec-archive-change/

- `SKILL.md` — Archive Complete (~1039 tok)

## .codex/skills/openspec-explore/

- `SKILL.md` — The Stance (~2309 tok)

## .codex/skills/openspec-propose/

- `SKILL.md` (~1161 tok)

## .github/

- `copilot-instructions.md` — Copilot Instructions (~551 tok)

## .github/prompts/

- `opsx-apply.prompt.md` — Implementing: <change-name> (schema: <schema-name>) (~1126 tok)
- `opsx-archive.prompt.md` — Archive Complete (~1233 tok)
- `opsx-explore.prompt.md` — The Stance (~1563 tok)
- `opsx-propose.prompt.md` (~1084 tok)

## .github/skills/openspec-apply-change/

- `SKILL.md` — Implementing: <change-name> (schema: <schema-name>) (~1190 tok)

## .github/skills/openspec-archive-change/

- `SKILL.md` — Archive Complete (~1039 tok)

## .github/skills/openspec-explore/

- `SKILL.md` — The Stance (~2309 tok)

## .github/skills/openspec-propose/

- `SKILL.md` (~1161 tok)

## .opencode/

- `.gitignore` — Git ignore rules (~17 tok)
- `package-lock.json` — npm lock file (~4435 tok)
- `package.json` — Node.js package manifest (~29 tok)

## .opencode/commands/

- `opsx-apply.md` — Implementing: <change-name> (schema: <schema-name>) (~1126 tok)
- `opsx-archive.md` — Archive Complete (~1233 tok)
- `opsx-explore.md` — The Stance (~1563 tok)
- `opsx-propose.md` (~1084 tok)

## .opencode/skills/openspec-apply-change/

- `SKILL.md` — Implementing: <change-name> (schema: <schema-name>) (~1190 tok)

## .opencode/skills/openspec-archive-change/

- `SKILL.md` — Archive Complete (~1039 tok)

## .opencode/skills/openspec-explore/

- `SKILL.md` — The Stance (~2309 tok)

## .opencode/skills/openspec-propose/

- `SKILL.md` (~1161 tok)

## .opencode/skills/simplify/

- `SKILL.md` — Simplify Codebase Skill (~1338 tok)

## .serena/

- `.gitignore` — Git ignore rules (~7 tok)
- `project.local.yml` — This file allows you to locally override settings in project.yml for development purposes. (~115 tok)
- `project.yml` — the name by which the project can be referenced within Serena (~2661 tok)

## .serena/memories/expat8/deploy/

- `2026-05-09-expat8-backend-fresh-deploy.md` (~372 tok)

## .serena/memories/expat8/speaking-foundation/

- `status.md` — Speaking Foundation Phase 0-3 — Status (~1157 tok)

## backend/

- `.dockerignore` — Docker ignore rules (~21 tok)
- `Dockerfile` — Docker container definition (~45 tok)
- `package-lock.json` — npm lock file (~9990 tok)
- `package.json` — Node.js package manifest (~129 tok)
- `README.md` — Project documentation (~239 tok)

## backend/db/

- `schema.sql` — Database schema (~4244 tok)

## backend/db/migrations/

- `20260504_add_adaptive_proficiency_system.sql` — SQL: tables: user_proficiency (~102 tok)
- `20260504_add_user_identity.sql` — SQL: tables: users, user_sessions, 1 alter(s) (~279 tok)
- `20260505_backend_managed_vocabulary_pool.sql` — SQL: tables: generation_runs, scheduler_locks, user_cached_words, 4 alter(s) (~534 tok)
- `20260506_backfill_user_state_unique_indexes.sql` (~568 tok)
- `20260506_language_native_proficiency_scale.sql` — SQL: 6 alter(s) (~286 tok)
- `20260506_user_proficiency_owner_indexes.sql` — SQL: 1 alter(s) (~358 tok)
- `20260507_fix_codebase_review_issues.sql` — Migration: fix-codebase-review-issues (~58 tok)
- `20260509_content_ingestion_v2_foundation.sql` — Migration: content-ingestion-v2-foundation (~1246 tok)
- `20260509_speaking_foundation.sql` — Migration: speaking-foundation (~858 tok)
- `20260510_article_vocabulary_suggestion_metadata.sql` — Migration: article-vocabulary-suggestion-metadata (~83 tok)
- `20260510_postgres_nonce_cache.sql` — Postgres-backed nonce cache for distributed replay protection. (~167 tok)
- `20260510_speaking_drill_completed.sql` — Migration: speaking-drill-completed (~478 tok)
- `20260510_srs_review_index.sql` — Partial index to speed up due-review-item queries in learningCards. (~85 tok)
- `20260511_exam_tables.sql` — Migration: add-vocabulary-exam (~691 tok)
- `20260512_add_blank_word.sql` — SQL: 1 alter(s) (~18 tok)
- `20260512_phrase_idiom_entry_types.sql` — Migration: phrase-idiom-exam (~124 tok)

## backend/db/seeds/

- `speaking_prompts_seed.sql` — Seed: 50 curated speaking prompts (A1-B1 level, work/daily/travel topics) (~3408 tok)

## backend/openspec/changes/mobile-local-first-card-selection/

- `.openspec.yaml` (~12 tok)

## backend/scripts/

- `verify_content_ingestion_migration.mjs` — REQUIRED_TABLES: main, findMissingTables, findMissingIndexes (~687 tok)

## backend/src/

- `app_credentials.js` — PostgreSQL-backed nonce cache for multi-instance replay protection. (~1672 tok)
- `app.js` — API routes: GET (5 endpoints) (~3621 tok)
- `article_processing_pipeline.js` — Exports ArticleProcessingPipeline (~1998 tok)
- `article_processing_worker.js` — Exports ArticleProcessingWorker (~691 tok)
- `article_term_extractor.js` — Exports extractCandidateTerms (~384 tok)
- `config.js` — Exports loadConfig (~1080 tok)
- `database.js` — Exports readSchemaSql, initializeDatabaseSchema (~142 tok)
- `generation_service.js` — Exports VocabularyGenerationService, parseVocabularyJson (~892 tok)
- `http_utils.js` — Exports readJson, sendJson (~117 tok)
- `ids.js` — Exports createId (~34 tok)
- `litellm_client.js` — Exports LiteLLMClient (~2767 tok)
- `logger.js` — Exports createLogger, sanitizeFields (~987 tok)
- `normalize.js` — Exports normalizeTerm (~32 tok)
- `postgres_word_store.js` — Exports PostgresWordStore (~33256 tok)
- `proficiency.js` — Exports CEFR_LEVELS, HSK_LEVELS, DEFAULT_PROFICIENCY_LEVEL, VALID_STUDY_RATINGS + 16 more (~1416 tok)
- `rate_limit.js` — Simple in-process sliding-window rate limiter. (~906 tok)
- `runtime.js` — Exports createStore, createBackendRuntime (~820 tok)
- `server.js` (~148 tok)
- `user_identity.js` — Exports DuplicateUserError, InvalidCredentialsError, InvalidRegistrationInputError, normalizeUserIdentifier + 5 more (~618 tok)
- `vocabulary_enrichment_adapter.js` — Exports VocabularyEnrichmentAdapter (~1505 tok)
- `vocabulary_pool_scheduler.js` — Exports VocabularyPoolScheduler (~1207 tok)
- `vocabulary_validator.js` — Exports validateVocabularyItem, normalizeSuggestionType (~692 tok)
- `word_store.js` — Exports SPEAKING_EVENT_TYPES, SPEAKING_SELF_RATINGS, WordStore (~28565 tok)
- `worker.js` — config: handleShutdown, tick (~1310 tok)

## backend/src/routes/

- `admin.js` — API routes: POST, GET, PATCH, DELETE (16 endpoints) (~3312 tok)
- `exam.js` — API routes: GET, POST (6 endpoints) (~1602 tok)

## backend/test/

- `api_logging.test.js` — lines: listen (~757 tok)
- `api.test.js` — Declares store (~18694 tok)
- `app_credentials.test.js` — activeCredential: signedHeaders (~1798 tok)
- `article_ingest_integration.test.js` — Integration tests: article ingest → processing state transitions → publish eligibility. (~2219 tok)
- `article_processing_pipeline.test.js` — Helpers (~2544 tok)
- `article_processing_worker.test.js` — Declares store (~1621 tok)
- `config.test.js` — Declares config (~725 tok)
- `database.test.js` — Declares schemaSql (~237 tok)
- `e2e_prod_test.mjs` — E2E test against a production backend. (~4252 tok)
- `e2e_smoke.test.js` — backendStore: listen, fetchJson, wordInput (~3683 tok)
- `exam.test.js` — Directly inject a user word state (bypasses SRS logic for speed). (~7291 tok)
- `generation_service.test.js` — items: wordInput (~1764 tok)
- `litellm_client.test.js` — Declares client (~571 tok)
- `logger.test.js` — Declares chunks (~484 tok)
- `postgres_integration.test.js` — testDatabaseUrl: resetSchema, listen, fetchJson, wordInput (~1270 tok)
- `postgres_word_store.test.js` — Declares store (~6198 tok)
- `proficiency.test.js` (~574 tok)
- `runtime.test.js` — Declares store (~264 tok)
- `user_identity.test.js` (~112 tok)
- `vocabulary_pool_scheduler.test.js` — store: schedulerConfig, wordInput (~798 tok)
- `vocabulary_validator.test.js` — Declares wordInput (~551 tok)
- `word_store.test.js` — Declares store (~8595 tok)

## backend/test/support/

- `app_credential_helpers.js` — Exports testAppCredential, loadTestConfig, signedFetchOptions (~466 tok)

## contracts/

- `api.md` — API Contracts (~18844 tok)

## docs/

- `20260506-adaptive-proficiency-code-review.md` — Adaptive Proficiency Code Review Summary (~360 tok)
- `20260506-adaptive-proficiency-migration-guide.md` — Adaptive Proficiency Migration Guide (~278 tok)
- `20260506-adaptive-proficiency-release-notes.md` — Release Notes: Adaptive Proficiency System (~255 tok)
- `20260506-language-native-proficiency-release-handoff.md` — Release Notes and Handoff: Language-Native Proficiency Scales (~560 tok)
- `20260506-language-native-proficiency-rollout.md` — Language-Native Proficiency Rollout (CEFR + HSK) (~689 tok)
- `20260506-multilanguage-chinese-research.md` — Nghien cuu ho tro da ngon ngu: uu tien hoc tu vung tieng Trung (~2731 tok)
- `20260507-mobile-backend-request-investigation.md` — 2026-05-07 Mobile Backend Request Investigation (~2713 tok)
- `20260508-app-runtime-review.md` — App Runtime Status Review - 2026-05-08 23:30 (~2181 tok)
- `20260509-card-freeze-investigation.md` — Investigation: App "treo" sau vài từ (~1507 tok)
- `20260509-expat8-backend-fresh-deploy-1507.md` — Deploy Report: expat8-backend Fresh Deploy (~332 tok)
- `20260509-expat8-phase-0-3-speaking-foundation.md` — Expat8 Phase 0-3 Months: Speaking Foundation (~5181 tok)
- `20260509-expat8-product-roadmap-2026-2028.md` — Expat8 Product Roadmap 2026-2028 (~3223 tok)
- `20260509-mobile-local-first-word-loading.md` — Mobile Local-First Word Loading Exploration (~3304 tok)
- `20260509-mobile-swipe-activity-uiux-investigation.md` — Mobile Swipe Activity UI/UX Investigation (~3344 tok)
- `20260509-speaking-audio-privacy.md` — Expat8 Speaking Audio Privacy - Phase 0-3 (~474 tok)
- `20260509-speaking-prompt-seed-scope.md` — Speaking Prompt Seed Scope - Phase 0-3 (~1227 tok)
- `20260509-swipe-right-to-left-new-word-invariant.md` — Investigation: Swipe Phải→Trái Chỉ Load Được 3 Từ Mới (~1542 tok)
- `20260510-article-processing-worker-deployment.md` — Article Processing Worker — Deployment Notes (~1063 tok)
- `20260530-project-roadmap-12-month.md` — Expat8 12-Month Project Roadmap (~5192 tok)
- `api-guide.md` — Operational API summary and contract invariants (~620 tok)
- `app-credential-security.md` — App Credential Security (~3196 tok)
- `architecture-guide.md` — Runtime topology, request pipeline, storage, and data-flow guide (~790 tok)
- `architecture.md` — Kiến trúc hệ thống Expat8 — Version 2 (~7138 tok)
- `backend-guide.md` — Backend service commands, entrypoints, auth, database, and worker notes (~780 tok)
- `canonical-release-path.md` — Canonical Release and Update Path (~810 tok)
- `chinese-language-e2e-investigation.md` — Investigation: Tiếng Trung E2E Flow (~2188 tok)
- `COMMIT_REPORT_20260509_1510.md` — Commit Report (~1378 tok)
- `COMMIT_REPORT_20260509_155944.md` — Commit Report (~1191 tok)
- `COMMIT_REPORT_20260509_184558.md` — Commit Report (~1115 tok)
- `COMMIT_REPORT_20260509_192657.md` — Commit Report (~1489 tok)
- `COMMIT_REPORT_20260509_204126.md` — Commit Report (~2312 tok)
- `COMMIT_REPORT_20260510_131500.md` — Commit Report (~1331 tok)
- `COMMIT_REPORT_20260510_202545.md` — Commit Report (~1374 tok)
- `COMMIT_REPORT_20260530_125603.md` — Commit Report (~2714 tok)
- `COMMIT_REPORT_20260530_172604.md` — Commit Report (~1843 tok)
- `dashboard-guide.md` — Next.js admin dashboard setup, environment, and admin workflow guide (~560 tok)
- `deployment-guide.md` — Local Compose and Z440 deployment guide (~760 tok)
- `developer-setup.md` — Full workspace local development setup guide (~980 tok)
- `expat8_logs_2026_05_07T16_39_51_937450Z_1.txt` — Expat8 mobile logs (~3685 tok)
- `index.md` — Expat8 Documentation Index (~575 tok)
- `mobile-guide.md` — Flutter/ObjectBox app architecture, config, card loading, and release build guide (~800 tok)
- `mobile-system-logging.md` — Mobile System Logging (~669 tok)
- `mvp-setup.md` — MVP Setup and Limitations (~2300 tok)
- `privacy-policy.md` — Privacy Policy — Expat8 (~703 tok)
- `project-overview.md` — Product scope, repo shape, source-of-truth rules, and invariants (~590 tok)
- `random-fallback-investigation.md` — Investigation: "Rất ít từ vựng sẵn sàng" khi mở app (~987 tok)
- `RELEASE_NOTES_9_9.md` — Release Notes: Beta Speaking Foundation (v9.9) (~1709 tok)
- `release-notes.md` — Release Notes (~537 tok)
- `seed-vocabulary.md` — Seed Vocabulary Bundling (~1192 tok)
- `testing-guide.md` — Backend, mobile, dashboard, migration, smoke, and docs verification commands (~560 tok)

## expat8-dashboard/

- `.gitignore` — Git ignore rules (~25 tok)
- `Dockerfile` — Docker container definition (~223 tok)
- `next-env.d.ts` — / <reference types="next" /> (~75 tok)
- `next.config.cjs` — Ensure Next.js produces a standalone server build so the Dockerfile (~47 tok)
- `next.config.mjs` — Next.js configuration (~55 tok)
- `package-lock.json` — npm lock file (~55905 tok)
- `package.json` — Node.js package manifest (~159 tok)
- `tsconfig.json` — TypeScript configuration (~208 tok)
- `tsconfig.tsbuildinfo` (~25042 tok)

## expat8-dashboard/public/

- `.keep` (~0 tok)

## expat8-dashboard/src/

- `types.ts` — Exports AdminArticle, VocabularyReviewItem, ExamResult, UserRow + 6 more (~640 tok)

## expat8-dashboard/src/app/

- `globals.css` — Styles: 41 rules, 16 vars, 2 media queries (~2519 tok)
- `layout.tsx` — metadata (~165 tok)
- `page.tsx` — dynamic — renders form, table (~919 tok)

## expat8-dashboard/src/app/api/certificate/[id]/

- `route.ts` — Next.js API route: GET (~128 tok)

## expat8-dashboard/src/app/articles/[id]/

- `page.tsx` — dynamic — renders form, table (~2155 tok)

## expat8-dashboard/src/app/articles/new/

- `page.tsx` — createArticle — renders form (~452 tok)

## expat8-dashboard/src/app/exam/

- `page.tsx` — dynamic — renders form, table (~840 tok)

## expat8-dashboard/src/app/ops/

- `page.tsx` — dynamic (~1846 tok)

## expat8-dashboard/src/app/review/

- `page.tsx` — dynamic — renders form, table (~804 tok)

## expat8-dashboard/src/app/speaking-prompts/

- `page.tsx` — dynamic — renders form, table (~1227 tok)

## expat8-dashboard/src/app/users/

- `page.tsx` — dynamic — renders table (~729 tok)

## expat8-dashboard/src/app/users/[id]/

- `page.tsx` — dynamic — renders table (~2472 tok)

## expat8-dashboard/src/components/

- `PageShell.tsx` — PageShell (~111 tok)
- `Sidebar.tsx` — Sidebar (~60 tok)
- `SidebarNav.tsx` — NAV_LINKS (~249 tok)
- `Toolbar.tsx` — Toolbar (~127 tok)

## expat8-dashboard/src/lib/

- `backend.ts` — Exports backendFetch (~695 tok)
- `config.ts` — Exports getAdminConfig (~119 tok)
- `db.ts` — Exports listAdminArticles, getAdminArticle, listArticleVocabulary, listPendingVocabulary + 6 more (~3783 tok)
- `ops-data.ts` — Exports SpeakingLoopHealth, LogArchiveRecord, HealthProbe, OpsOverview + 6 more (~1920 tok)

## mobile/

- `.flutter-plugins` — This is a generated file; do not edit or check into version control. (~568 tok)
- `.flutter-plugins-dependencies` (~2311 tok)
- `.gitignore` — Git ignore rules (~190 tok)
- `.metadata` — This file tracks properties of this Flutter project. (~455 tok)
- `analysis_options.yaml` (~27 tok)
- `expat8_language_app.iml` (~225 tok)
- `pubspec.yaml` — Dart/Flutter package manifest (~211 tok)
- `README.md` — Project documentation (~292 tok)

## mobile/.claude/commands/opsx/

- `apply.md` — Implementing: <change-name> (schema: <schema-name>) (~1146 tok)
- `archive.md` — Archive Complete (~1254 tok)
- `explore.md` — The Stance (~1586 tok)
- `propose.md` (~1104 tok)

## mobile/.claude/skills/openspec-apply-change/

- `SKILL.md` — Implementing: <change-name> (schema: <schema-name>) (~1190 tok)

## mobile/.claude/skills/openspec-archive-change/

- `SKILL.md` — Archive Complete (~1039 tok)

## mobile/.claude/skills/openspec-explore/

- `SKILL.md` — The Stance (~2309 tok)

## mobile/.claude/skills/openspec-propose/

- `SKILL.md` (~1161 tok)

## mobile/.codex/skills/openspec-apply-change/

- `SKILL.md` — Implementing: <change-name> (schema: <schema-name>) (~1190 tok)

## mobile/.codex/skills/openspec-archive-change/

- `SKILL.md` — Archive Complete (~1039 tok)

## mobile/.codex/skills/openspec-explore/

- `SKILL.md` — The Stance (~2309 tok)

## mobile/.codex/skills/openspec-propose/

- `SKILL.md` (~1161 tok)

## mobile/.dart_tool/

- `package_config_subset` — Declares 2 (~4718 tok)
- `package_config.json` (~6278 tok)
- `version` (~2 tok)

## mobile/.dart_tool/build_resolvers/

- `sdk.sum.deps` (~58 tok)

## mobile/.dart_tool/dartpad/

- `web_plugin_registrant.dart` — Flutter web plugin registrant file. (~282 tok)

## mobile/.dart_tool/flutter_build/

- `dart_plugin_registrant.dart` — This file is generated from template in file `flutter_tools/lib/src/flutter_plugins.dart`. (~999 tok)

## mobile/.dart_tool/flutter_build/07428d6725df74e11cbe763f9411fbe4/

- `_composite.stamp` (~7 tok)
- `.filecache` (~57201 tok)
- `android_aot_bundle_release_android-arm.stamp` (~64 tok)
- `android_aot_bundle_release_android-arm64.stamp` (~63 tok)
- `android_aot_bundle_release_android-x64.stamp` (~62 tok)
- `android_aot_release_android-arm.stamp` (~150 tok)
- `android_aot_release_android-arm64.stamp` (~150 tok)
- `android_aot_release_android-x64.stamp` (~149 tok)
- `aot_android_asset_bundle.stamp` (~2720 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `flutter_android_aot_bundle_release_android-arm.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-x64.d` (~1 tok)
- `flutter_android_aot_release_android-arm.d` (~1 tok)
- `flutter_android_aot_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_release_android-x64.d` (~1 tok)
- `flutter_assets.d` (~2547 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~32691 tok)
- `kernel_snapshot_program.stamp` (~33583 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~504 tok)

## mobile/.dart_tool/flutter_build/3e05e391e7be3015fb43064d651d9f3a/

- `_composite.stamp` (~7 tok)
- `.filecache` (~56852 tok)
- `android_aot_bundle_release_android-arm.stamp` (~64 tok)
- `android_aot_bundle_release_android-arm64.stamp` (~63 tok)
- `android_aot_bundle_release_android-x64.stamp` (~62 tok)
- `android_aot_release_android-arm.stamp` (~150 tok)
- `android_aot_release_android-arm64.stamp` (~150 tok)
- `android_aot_release_android-x64.stamp` (~149 tok)
- `aot_android_asset_bundle.stamp` (~2720 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `flutter_android_aot_bundle_release_android-arm.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-x64.d` (~1 tok)
- `flutter_android_aot_release_android-arm.d` (~1 tok)
- `flutter_android_aot_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_release_android-x64.d` (~1 tok)
- `flutter_assets.d` (~2547 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~32483 tok)
- `kernel_snapshot_program.stamp` (~33371 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~504 tok)

## mobile/.dart_tool/flutter_build/4911fd291998fe4f4ba374cb7b891d08/

- `.filecache` (~57063 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `debug_android_application.stamp` (~2839 tok)
- `flutter_assets.d` (~2540 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~32708 tok)
- `kernel_snapshot_program.stamp` (~33601 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~509 tok)

## mobile/.dart_tool/flutter_build/61d153fe3a87fabc0492c0f77fe25763/

- `_composite.stamp` (~7 tok)
- `.filecache` (~56852 tok)
- `android_aot_bundle_release_android-arm.stamp` (~64 tok)
- `android_aot_bundle_release_android-arm64.stamp` (~63 tok)
- `android_aot_bundle_release_android-x64.stamp` (~62 tok)
- `android_aot_release_android-arm.stamp` (~150 tok)
- `android_aot_release_android-arm64.stamp` (~150 tok)
- `android_aot_release_android-x64.stamp` (~149 tok)
- `aot_android_asset_bundle.stamp` (~2720 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `flutter_android_aot_bundle_release_android-arm.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-x64.d` (~1 tok)
- `flutter_android_aot_release_android-arm.d` (~1 tok)
- `flutter_android_aot_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_release_android-x64.d` (~1 tok)
- `flutter_assets.d` (~2547 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~32483 tok)
- `kernel_snapshot_program.stamp` (~33371 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~504 tok)

## mobile/.dart_tool/flutter_build/70483856fee8e7737ea26717e4c4a61c/

- `.filecache` (~57063 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `debug_android_application.stamp` (~2839 tok)
- `flutter_assets.d` (~2540 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~32708 tok)
- `kernel_snapshot_program.stamp` (~33601 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~509 tok)

## mobile/.dart_tool/flutter_build/a49d52765388b2bc57d6ea40598e5e33/

- `_composite.stamp` (~7 tok)
- `.filecache` (~57232 tok)
- `android_aot_bundle_release_android-arm.stamp` (~64 tok)
- `android_aot_bundle_release_android-arm64.stamp` (~63 tok)
- `android_aot_bundle_release_android-x64.stamp` (~62 tok)
- `android_aot_release_android-arm.stamp` (~150 tok)
- `android_aot_release_android-arm64.stamp` (~150 tok)
- `android_aot_release_android-x64.stamp` (~149 tok)
- `aot_android_asset_bundle.stamp` (~2720 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `flutter_android_aot_bundle_release_android-arm.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-x64.d` (~1 tok)
- `flutter_android_aot_release_android-arm.d` (~1 tok)
- `flutter_android_aot_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_release_android-x64.d` (~1 tok)
- `flutter_assets.d` (~2547 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~32708 tok)
- `kernel_snapshot_program.stamp` (~33601 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~504 tok)

## mobile/.dart_tool/flutter_build/a5eb4af7e6453ba7e880cbb12e957e05/

- `_composite.stamp` (~7 tok)
- `.filecache` (~57201 tok)
- `android_aot_bundle_release_android-arm.stamp` (~64 tok)
- `android_aot_bundle_release_android-arm64.stamp` (~63 tok)
- `android_aot_bundle_release_android-x64.stamp` (~62 tok)
- `android_aot_release_android-arm.stamp` (~150 tok)
- `android_aot_release_android-arm64.stamp` (~150 tok)
- `android_aot_release_android-x64.stamp` (~149 tok)
- `aot_android_asset_bundle.stamp` (~2720 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `flutter_android_aot_bundle_release_android-arm.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-x64.d` (~1 tok)
- `flutter_android_aot_release_android-arm.d` (~1 tok)
- `flutter_android_aot_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_release_android-x64.d` (~1 tok)
- `flutter_assets.d` (~2547 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~32691 tok)
- `kernel_snapshot_program.stamp` (~33583 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~504 tok)

## mobile/.dart_tool/flutter_build/b31e1d2bebdba842960398a6539d4cf0/

- `_composite.stamp` (~7 tok)
- `.filecache` (~57232 tok)
- `android_aot_bundle_release_android-arm.stamp` (~64 tok)
- `android_aot_bundle_release_android-arm64.stamp` (~63 tok)
- `android_aot_bundle_release_android-x64.stamp` (~62 tok)
- `android_aot_release_android-arm.stamp` (~150 tok)
- `android_aot_release_android-arm64.stamp` (~150 tok)
- `android_aot_release_android-x64.stamp` (~149 tok)
- `aot_android_asset_bundle.stamp` (~2720 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `flutter_android_aot_bundle_release_android-arm.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-x64.d` (~1 tok)
- `flutter_android_aot_release_android-arm.d` (~1 tok)
- `flutter_android_aot_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_release_android-x64.d` (~1 tok)
- `flutter_assets.d` (~2547 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~32708 tok)
- `kernel_snapshot_program.stamp` (~33601 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~504 tok)

## mobile/.dart_tool/flutter_build/bd02b0f15e51ffe2d6de0c1de54e86d0/

- `_composite.stamp` (~7 tok)
- `.filecache` (~56852 tok)
- `android_aot_bundle_release_android-arm.stamp` (~64 tok)
- `android_aot_bundle_release_android-arm64.stamp` (~63 tok)
- `android_aot_bundle_release_android-x64.stamp` (~62 tok)
- `android_aot_release_android-arm.stamp` (~150 tok)
- `android_aot_release_android-arm64.stamp` (~150 tok)
- `android_aot_release_android-x64.stamp` (~149 tok)
- `aot_android_asset_bundle.stamp` (~2720 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `flutter_android_aot_bundle_release_android-arm.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-x64.d` (~1 tok)
- `flutter_android_aot_release_android-arm.d` (~1 tok)
- `flutter_android_aot_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_release_android-x64.d` (~1 tok)
- `flutter_assets.d` (~2547 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~32483 tok)
- `kernel_snapshot_program.stamp` (~33371 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~504 tok)

## mobile/.dart_tool/flutter_build/c5696d2059e1fc06d585f547380f0883/

- `_composite.stamp` (~7 tok)
- `.filecache` (~57201 tok)
- `android_aot_bundle_release_android-arm.stamp` (~64 tok)
- `android_aot_bundle_release_android-arm64.stamp` (~63 tok)
- `android_aot_bundle_release_android-x64.stamp` (~62 tok)
- `android_aot_release_android-arm.stamp` (~150 tok)
- `android_aot_release_android-arm64.stamp` (~150 tok)
- `android_aot_release_android-x64.stamp` (~149 tok)
- `aot_android_asset_bundle.stamp` (~2720 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `flutter_android_aot_bundle_release_android-arm.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-x64.d` (~1 tok)
- `flutter_android_aot_release_android-arm.d` (~1 tok)
- `flutter_android_aot_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_release_android-x64.d` (~1 tok)
- `flutter_assets.d` (~2547 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~32691 tok)
- `kernel_snapshot_program.stamp` (~33583 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~504 tok)

## mobile/.dart_tool/flutter_build/c59cdf0d8bfb778b2f9a580239314881/

- `_composite.stamp` (~7 tok)
- `.filecache` (~57025 tok)
- `android_aot_bundle_release_android-arm.stamp` (~64 tok)
- `android_aot_bundle_release_android-arm64.stamp` (~63 tok)
- `android_aot_bundle_release_android-x64.stamp` (~62 tok)
- `android_aot_release_android-arm.stamp` (~150 tok)
- `android_aot_release_android-arm64.stamp` (~150 tok)
- `android_aot_release_android-x64.stamp` (~149 tok)
- `aot_android_asset_bundle.stamp` (~2720 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `flutter_android_aot_bundle_release_android-arm.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-x64.d` (~1 tok)
- `flutter_android_aot_release_android-arm.d` (~1 tok)
- `flutter_android_aot_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_release_android-x64.d` (~1 tok)
- `flutter_assets.d` (~2547 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~32688 tok)
- `kernel_snapshot_program.stamp` (~33581 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~504 tok)

## mobile/.dart_tool/flutter_build/d78bb27d9cf8909e6e3e0c547dfa94d0/

- `.filecache` (~57063 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `debug_android_application.stamp` (~2839 tok)
- `flutter_assets.d` (~2540 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~32708 tok)
- `kernel_snapshot_program.stamp` (~33601 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~509 tok)

## mobile/.dart_tool/flutter_build/e7d5bee05f88fd67dae5530599fd4764/

- `.filecache` (~57063 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `debug_android_application.stamp` (~2839 tok)
- `flutter_assets.d` (~2540 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~32708 tok)
- `kernel_snapshot_program.stamp` (~33601 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~509 tok)

## mobile/.dart_tool/flutter_build/efb0b888c4c211865005c0e398a481ed/

- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)

## mobile/lib/

- `main.dart` — Stateful widget: LanguageLearningApp (~2344 tok)

## mobile/lib/src/api/models/

- `speaking_models.dart` — / Weekly speaking summary returned by `GET /v1/speaking/summary`. (~609 tok)

## mobile/lib/src/exam/

- `exam_certificate_screen.dart` — / Public certificate view screen. (~1698 tok)

## mobile/lib/src/speaking/

- `speaking_drill_screen.dart` — / 3-minute speaking drill. (~3273 tok)
- `speaking_repository.dart` — / Speaking event types matching the backend enum. (~4724 tok)
- `speaking_summary_screen.dart` — / Weekly speaking summary screen. (~1466 tok)

## mobile/lib/src/ui/

- `learning_screen.dart` — Stateful widget: LearningScreen (~7682 tok)

## mobile/test/

- `speaking_test.dart` — ---- Minimal fake audio service (no real mic/plugin) ---- (~3613 tok)

## openspec/changes/phase-0-trust-and-release-readiness/

- `design.md` — Context (~2003 tok)
- `proposal.md` — Why (~1091 tok)
- `tasks.md` — 1. Mobile Device Verification (~1536 tok)

## openspec/changes/phase-0-trust-and-release-readiness/specs/admin-api-documentation/

- `spec.md` — MODIFIED Requirements (~909 tok)

## openspec/changes/phase-0-trust-and-release-readiness/specs/learning-cards-api/

- `spec.md` — MODIFIED Requirements (~679 tok)

## openspec/changes/phase-0-trust-and-release-readiness/specs/mobile-exam-navigation/

- `spec.md` — MODIFIED Requirements (~579 tok)

## openspec/changes/phase-0-trust-and-release-readiness/specs/mobile-release-android/

- `spec.md` — MODIFIED Requirements (~670 tok)

## openspec/changes/phase-0-trust-and-release-readiness/specs/mobile-word-prefetch/

- `spec.md` — MODIFIED Requirements (~762 tok)

## openspec/changes/phase-0-trust-and-release-readiness/specs/phase-0-contract-parity/

- `spec.md` — ADDED Requirements (~549 tok)

## openspec/changes/phase-0-trust-and-release-readiness/specs/phase-0-dashboard-correctness/

- `spec.md` — ADDED Requirements (~555 tok)

## openspec/changes/phase-0-trust-and-release-readiness/specs/phase-0-release-path/

- `spec.md` — ADDED Requirements (~644 tok)

## openspec/changes/phase-0-trust-and-release-readiness/specs/phase-0-replay-protection-health/

- `spec.md` — ADDED Requirements (~414 tok)

## openspec/changes/phase-0-trust-and-release-readiness/specs/phase-0-schema-migration-parity/

- `spec.md` — ADDED Requirements (~444 tok)

## openspec/changes/phase-1-cohesive-daily-speaking-loop/

- `design.md` — Context (~1574 tok)
- `proposal.md` — Why (~871 tok)
- `tasks.md` — 1. Backend: loop_completed event type (~1729 tok)

## openspec/changes/phase-1-cohesive-daily-speaking-loop/specs/dashboard-loop-health/

- `spec.md` — ADDED Requirements (~320 tok)

## openspec/changes/phase-1-cohesive-daily-speaking-loop/specs/learner-loop-completion-signal/

- `spec.md` — ADDED Requirements (~438 tok)

## openspec/changes/phase-1-cohesive-daily-speaking-loop/specs/mobile-speaking-drill/

- `spec.md` — MODIFIED Requirements (~335 tok)

## openspec/changes/phase-1-cohesive-daily-speaking-loop/specs/mobile-speaking-session/

- `spec.md` — MODIFIED Requirements (~208 tok)

## openspec/changes/phase-1-cohesive-daily-speaking-loop/specs/mobile-weekly-speaking-summary/

- `spec.md` — ADDED Requirements (~364 tok)

## openspec/changes/phase-1-cohesive-daily-speaking-loop/specs/speaking-study-events/

- `spec.md` — MODIFIED Requirements (~298 tok)

## openspec/changes/phase-1-cohesive-daily-speaking-loop/specs/worker-graceful-shutdown/

- `spec.md` — ADDED Requirements (~230 tok)

## openspec/changes/phase-2-content-depth-and-operational-coverage/

- `design.md` — Context (~1009 tok)
- `proposal.md` — Why (~805 tok)
- `tasks.md` — 1. Backend — Content Pipeline Health Endpoint (~1101 tok)

## openspec/changes/phase-2-content-depth-and-operational-coverage/specs/content-pipeline-observability/

- `spec.md` — ADDED Requirements (~378 tok)

## openspec/changes/phase-2-content-depth-and-operational-coverage/specs/phase-2-exit-gate/

- `spec.md` — ADDED Requirements (~397 tok)

## openspec/changes/phase-3-lightweight-ai-feedback/

- `design.md` — Context (~1660 tok)
- `proposal.md` — Why (~960 tok)
- `tasks.md` — Tasks: phase-3-lightweight-ai-feedback (~2832 tok)

## openspec/changes/phase-3-lightweight-ai-feedback/specs/content-pipeline-observability/

- `spec.md` — MODIFIED Requirements (~393 tok)

## openspec/changes/phase-3-lightweight-ai-feedback/specs/drill-feedback-jobs/

- `spec.md` — ADDED Requirements (~659 tok)

## openspec/changes/phase-3-lightweight-ai-feedback/specs/next-practice-recommendation/

- `spec.md` — ADDED Requirements (~557 tok)

## openspec/changes/phase-3-lightweight-ai-feedback/specs/speaking-study-events/

- `spec.md` — MODIFIED Requirements (~287 tok)
