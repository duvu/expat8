# anatomy.md

> Auto-maintained by OpenWolf. Last scanned: 2026-05-12T11:00:00.199Z
> Files: 519 tracked | Anatomy hits: 0 | Misses: 0

## ./

- `.gitignore` — Git ignore rules (~27 tok)
- `AGENTS.md` — AGENTS.md (~513 tok)
- `CLAUDE.md` — OpenWolf (~1610 tok)
- `docker-compose.yml` — Docker Compose services (~1005 tok)
- `expat8.code-workspace` (~44 tok)
- `README.md` — Project documentation (~780 tok)

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

- `copilot-instructions.md` — Copilot Instructions (~553 tok)

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

- `2026-05-09-expat8-backend-fresh-deploy.md` (~373 tok)

## .serena/memories/expat8/speaking-foundation/

- `status.md` — Speaking Foundation Phase 0-3 — Status (~1156 tok)

## backend/

- `.dockerignore` — Docker ignore rules (~21 tok)
- `Dockerfile` — Docker container definition (~45 tok)
- `package-lock.json` — npm lock file (~9990 tok)
- `package.json` — Node.js package manifest (~129 tok)
- `README.md` — Project documentation (~239 tok)

## backend/db/

- `schema.sql` — Database schema (~1965 tok)

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
- `20260512_phrase_idiom_entry_types.sql` — Migration: phrase-idiom-exam (~124 tok)

## backend/db/seeds/

- `speaking_prompts_seed.sql` — Seed: 50 curated speaking prompts (A1-B1 level, work/daily/travel topics) (~3408 tok)

## backend/openspec/changes/mobile-local-first-card-selection/

- `.openspec.yaml` (~12 tok)

## backend/scripts/

- `verify_content_ingestion_migration.mjs` — REQUIRED_TABLES: main, findMissingTables, findMissingIndexes (~687 tok)

## backend/src/

- `app_credentials.js` — PostgreSQL-backed nonce cache for multi-instance replay protection. (~1614 tok)
- `app.js` — Create the default rate limiter set for production use. (~9731 tok)
- `article_processing_pipeline.js` — Exports ArticleProcessingPipeline (~1998 tok)
- `article_processing_worker.js` — Exports ArticleProcessingWorker (~691 tok)
- `article_term_extractor.js` — Exports extractCandidateTerms (~384 tok)
- `config.js` — Exports loadConfig (~1087 tok)
- `database.js` — Exports readSchemaSql, initializeDatabaseSchema (~142 tok)
- `generation_service.js` — Exports VocabularyGenerationService, parseVocabularyJson (~892 tok)
- `http_utils.js` — Exports readJson, sendJson (~117 tok)
- `ids.js` — Exports createId (~34 tok)
- `litellm_client.js` — Exports LiteLLMClient (~2506 tok)
- `logger.js` — Exports createLogger, sanitizeFields (~987 tok)
- `normalize.js` — Exports normalizeTerm (~32 tok)
- `postgres_word_store.js` — Exports PostgresWordStore (~19456 tok)
- `proficiency.js` — Exports CEFR_LEVELS, HSK_LEVELS, DEFAULT_PROFICIENCY_LEVEL, VALID_STUDY_RATINGS + 16 more (~1416 tok)
- `rate_limit.js` — Simple in-process sliding-window rate limiter. (~906 tok)
- `runtime.js` — Exports createStore, createBackendRuntime (~820 tok)
- `server.js` (~148 tok)
- `user_identity.js` — Exports DuplicateUserError, InvalidCredentialsError, InvalidRegistrationInputError, normalizeUserIdentifier + 5 more (~618 tok)
- `vocabulary_enrichment_adapter.js` — Exports VocabularyEnrichmentAdapter (~1498 tok)
- `vocabulary_pool_scheduler.js` — Exports VocabularyPoolScheduler (~1207 tok)
- `vocabulary_validator.js` — Exports validateVocabularyItem, normalizeSuggestionType (~692 tok)
- `word_store.js` — Exports SPEAKING_EVENT_TYPES, SPEAKING_SELF_RATINGS, WordStore (~27382 tok)
- `worker.js` — config: tick (~478 tok)

## backend/src/routes/

- `exam.js` — API routes: GET, POST (6 endpoints) (~1602 tok)

## backend/test/

- `api_logging.test.js` — lines: listen (~757 tok)
- `api.test.js` — Declares store (~15722 tok)
- `app_credentials.test.js` — activeCredential: signedHeaders (~1798 tok)
- `article_ingest_integration.test.js` — Integration tests: article ingest → processing state transitions → publish eligibility. (~2219 tok)
- `article_processing_pipeline.test.js` — Helpers (~2544 tok)
- `article_processing_worker.test.js` — Declares store (~1621 tok)
- `config.test.js` — Declares config (~720 tok)
- `database.test.js` — Declares schemaSql (~237 tok)
- `e2e_prod_test.mjs` — E2E test against production backend at https://expat8.x51.vn (~4170 tok)
- `e2e_smoke.test.js` — backendStore: listen, fetchJson, wordInput (~3683 tok)
- `exam.test.js` — Directly inject a user word state (bypasses SRS logic for speed). (~6878 tok)
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
- `word_store.test.js` — Declares store (~8006 tok)

## backend/test/support/

- `app_credential_helpers.js` — Exports testAppCredential, loadTestConfig, signedFetchOptions (~466 tok)

## contracts/

- `api.md` — API Contracts (~5704 tok)

## docs/

- `20260506-adaptive-proficiency-code-review.md` — Adaptive Proficiency Code Review Summary (~360 tok)
- `20260506-adaptive-proficiency-migration-guide.md` — Adaptive Proficiency Migration Guide (~278 tok)
- `20260506-adaptive-proficiency-release-notes.md` — Release Notes: Adaptive Proficiency System (~255 tok)
- `20260506-language-native-proficiency-release-handoff.md` — Release Notes and Handoff: Language-Native Proficiency Scales (~560 tok)
- `20260506-language-native-proficiency-rollout.md` — Language-Native Proficiency Rollout (CEFR + HSK) (~689 tok)
- `20260506-multilanguage-chinese-research.md` — Nghien cuu ho tro da ngon ngu: uu tien hoc tu vung tieng Trung (~2731 tok)
- `20260507-mobile-backend-request-investigation.md` — 2026-05-07 Mobile Backend Request Investigation (~2715 tok)
- `20260508-app-runtime-review.md` — App Runtime Status Review - 2026-05-08 23:30 (~2186 tok)
- `20260509-card-freeze-investigation.md` — Investigation: App "treo" sau vài từ (~1507 tok)
- `20260509-expat8-backend-fresh-deploy-1507.md` — Deploy Report: expat8-backend Fresh Deploy (~330 tok)
- `20260509-expat8-phase-0-3-speaking-foundation.md` — Expat8 Phase 0-3 Months: Speaking Foundation (~5181 tok)
- `20260509-expat8-product-roadmap-2026-2028.md` — Expat8 Product Roadmap 2026-2028 (~3223 tok)
- `20260509-mobile-local-first-word-loading.md` — Mobile Local-First Word Loading Exploration (~3304 tok)
- `20260509-mobile-swipe-activity-uiux-investigation.md` — Mobile Swipe Activity UI/UX Investigation (~3344 tok)
- `20260509-speaking-audio-privacy.md` — Expat8 Speaking Audio Privacy - Phase 0-3 (~474 tok)
- `20260509-speaking-prompt-seed-scope.md` — Speaking Prompt Seed Scope - Phase 0-3 (~1227 tok)
- `20260509-swipe-right-to-left-new-word-invariant.md` — Investigation: Swipe Phải→Trái Chỉ Load Được 3 Từ Mới (~1542 tok)
- `20260510-article-processing-worker-deployment.md` — Article Processing Worker — Deployment Notes (~1064 tok)
- `app-credential-security.md` — App Credential Security (~3196 tok)
- `architecture.md` — Kiến trúc hệ thống Expat8 — Version 2 (~7138 tok)
- `chinese-language-e2e-investigation.md` — Investigation: Tiếng Trung E2E Flow (~2188 tok)
- `COMMIT_REPORT_20260509_1510.md` — Commit Report (~1377 tok)
- `COMMIT_REPORT_20260509_155944.md` — Commit Report (~1191 tok)
- `COMMIT_REPORT_20260509_184558.md` — Commit Report (~1115 tok)
- `COMMIT_REPORT_20260509_192657.md` — Commit Report (~1488 tok)
- `COMMIT_REPORT_20260509_204126.md` — Commit Report (~2312 tok)
- `COMMIT_REPORT_20260510_131500.md` — Commit Report (~1331 tok)
- `COMMIT_REPORT_20260510_202545.md` — Commit Report (~1373 tok)
- `expat8_logs_2026_05_07T16_39_51_937450Z_1.txt` — Expat8 mobile logs (~3682 tok)
- `mobile-system-logging.md` — Mobile System Logging (~670 tok)
- `mvp-setup.md` — MVP Setup and Limitations (~2300 tok)
- `random-fallback-investigation.md` — Investigation: "Rất ít từ vựng sẵn sàng" khi mở app (~987 tok)
- `RELEASE_NOTES_9_9.md` — Release Notes: Beta Speaking Foundation (v9.9) (~1709 tok)
- `release-notes.md` — Release Notes (~537 tok)
- `seed-vocabulary.md` — Seed Vocabulary Bundling (~1193 tok)

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

- `globals.css` — Styles: 29 rules, 14 vars, 1 media queries (~1928 tok)
- `layout.tsx` — metadata (~114 tok)
- `page.tsx` — dynamic — renders form, table (~992 tok)

## expat8-dashboard/src/app/articles/[id]/

- `page.tsx` — dynamic — renders form, table (~960 tok)

## expat8-dashboard/src/app/articles/new/

- `page.tsx` — createArticle — renders form (~452 tok)

## expat8-dashboard/src/app/exam/

- `page.tsx` — dynamic — renders form, table (~861 tok)

## expat8-dashboard/src/app/review/

- `page.tsx` — dynamic — renders form, table (~789 tok)

## expat8-dashboard/src/app/speaking-prompts/

- `page.tsx` — dynamic — renders form, table (~1214 tok)

## expat8-dashboard/src/app/users/

- `page.tsx` — dynamic — renders table (~750 tok)

## expat8-dashboard/src/app/users/[id]/

- `page.tsx` — dynamic — renders table (~1243 tok)

## expat8-dashboard/src/lib/

- `backend.ts` — Exports backendFetch (~695 tok)
- `config.ts` — Exports getAdminConfig (~119 tok)
- `db.ts` — Exports listAdminArticles, getAdminArticle, listArticleVocabulary, listPendingVocabulary + 6 more (~3783 tok)

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

## mobile/.github/prompts/

- `opsx-apply.prompt.md` — Implementing: <change-name> (schema: <schema-name>) (~1126 tok)
- `opsx-archive.prompt.md` — Archive Complete (~1233 tok)
- `opsx-explore.prompt.md` — The Stance (~1563 tok)
- `opsx-propose.prompt.md` (~1084 tok)

## mobile/.github/skills/openspec-apply-change/

- `SKILL.md` — Implementing: <change-name> (schema: <schema-name>) (~1190 tok)

## mobile/.github/skills/openspec-archive-change/

- `SKILL.md` — Archive Complete (~1039 tok)

## mobile/.github/skills/openspec-explore/

- `SKILL.md` — The Stance (~2309 tok)

## mobile/.github/skills/openspec-propose/

- `SKILL.md` (~1161 tok)

## mobile/android/

- `.gitignore` — Git ignore rules (~68 tok)
- `build.gradle.kts` — Gradle Kotlin build configuration (~138 tok)
- `expat8_language_app_android.iml` (~427 tok)
- `gradle.properties` (~45 tok)
- `gradlew` — ############################################################################# (~1326 tok)
- `gradlew.bat` (~642 tok)
- `local.properties` (~42 tok)
- `README.md` — Project documentation (~82 tok)
- `settings.gradle.kts` — Gradle Kotlin settings (~198 tok)

## mobile/android/.gradle/

- `file-system.probe` (~3 tok)

## mobile/android/.gradle/8.10.2/

- `gc.properties` (~0 tok)

## mobile/android/.gradle/8.10.2/dependencies-accessors/

- `gc.properties` (~0 tok)

## mobile/android/.gradle/buildOutputCleanup/

- `cache.properties` — Mon May 04 21:39:00 ICT 2026 (~14 tok)

## mobile/android/.gradle/kotlin/errors/

- `errors-1778341142851.log` (~2160 tok)

## mobile/android/.gradle/vcs-1/

- `gc.properties` (~0 tok)

## mobile/android/.kotlin/errors/

- `errors-1778341142851.log` (~2160 tok)

## mobile/android/app/

- `build.gradle.kts` — Gradle Kotlin build configuration (~364 tok)

## mobile/android/app/.cxx/Debug/27596y4e/

- `hash_key.txt` — Values used to calculate the hash in this folder name. (~308 tok)

## mobile/android/app/.cxx/Debug/27596y4e/arm64-v8a/

- `additional_project_files.txt` (~0 tok)
- `android_gradle_build_mini.json` (~170 tok)
- `android_gradle_build.json` (~271 tok)
- `build_file_index.txt` (~25 tok)
- `build.ninja` — CMAKE generated file: DO NOT EDIT! (~6185 tok)
- `cmake_install.cmake` — Install script for directory: /home/beou/snap/flutter/common/flutter/packages/flutter_tools/gradle/src/main/groovy (~485 tok)
- `CMakeCache.txt` — This is the CMakeCache file. (~4125 tok)
- `metadata_generation_command.txt` (~264 tok)
- `prefab_config.json` (~12 tok)
- `symbol_folder_index.txt` (~24 tok)

## mobile/android/app/.cxx/Debug/27596y4e/arm64-v8a/.cmake/api/v1/query/client-agp/

- `cache-v2` (~0 tok)
- `cmakeFiles-v1` (~0 tok)
- `codemodel-v2` (~0 tok)

## mobile/android/app/.cxx/Debug/27596y4e/arm64-v8a/.cmake/api/v1/reply/

- `cache-v2-f1048ae033bfed1af0a7.json` — Declares of (~7760 tok)
- `cmakeFiles-v1-3813a372d1ac11b54828.json` (~7509 tok)
- `codemodel-v2-f72146371ef1f86589e6.json` (~207 tok)
- `directory-.-Debug-f5ebdc15457944623624.json` (~44 tok)
- `index-2026-05-05T12-08-18-0017.json` (~448 tok)

## mobile/android/app/.cxx/Debug/27596y4e/arm64-v8a/CMakeFiles/

- `cmake.check_cache` — This file is generated by cmake for dependency checking of the CMakeCache.txt file (~23 tok)
- `CMakeOutput.log` (~11493 tok)
- `rules.ninja` — CMAKE generated file: DO NOT EDIT! (~404 tok)
- `TargetDirectories.txt` (~54 tok)

## mobile/android/app/.cxx/Debug/27596y4e/arm64-v8a/CMakeFiles/3.22.1-g37088a8/

- `CMakeCCompiler.cmake` (~920 tok)
- `CMakeCXXCompiler.cmake` (~1773 tok)
- `CMakeSystem.cmake` (~123 tok)

## mobile/android/app/.cxx/Debug/27596y4e/arm64-v8a/CMakeFiles/3.22.1-g37088a8/CompilerIdC/

- `CMakeCCompilerId.c` — ifdef __cplusplus (~7101 tok)
- `CMakeCCompilerId.o` (~1613 tok)

## mobile/android/app/.cxx/Debug/27596y4e/arm64-v8a/CMakeFiles/3.22.1-g37088a8/CompilerIdCXX/

- `CMakeCXXCompilerId.cpp` (~7028 tok)
- `CMakeCXXCompilerId.o` (~1615 tok)

## mobile/android/app/.cxx/Debug/27596y4e/armeabi-v7a/

- `additional_project_files.txt` (~0 tok)
- `android_gradle_build_mini.json` (~171 tok)
- `android_gradle_build.json` (~272 tok)
- `build_file_index.txt` (~25 tok)
- `build.ninja` — CMAKE generated file: DO NOT EDIT! (~6188 tok)
- `cmake_install.cmake` — Install script for directory: /home/beou/snap/flutter/common/flutter/packages/flutter_tools/gradle/src/main/groovy (~485 tok)
- `CMakeCache.txt` — This is the CMakeCache file. (~4128 tok)
- `metadata_generation_command.txt` (~266 tok)
- `prefab_config.json` (~12 tok)
- `symbol_folder_index.txt` (~24 tok)

## mobile/android/app/.cxx/Debug/27596y4e/armeabi-v7a/.cmake/api/v1/query/client-agp/

- `cache-v2` (~0 tok)
- `cmakeFiles-v1` (~0 tok)
- `codemodel-v2` (~0 tok)

## mobile/android/app/.cxx/Debug/27596y4e/armeabi-v7a/.cmake/api/v1/reply/

- `cache-v2-f33639f025674a7d5f2b.json` — Declares of (~7763 tok)
- `cmakeFiles-v1-e22bef0e02493b2b09a0.json` (~7512 tok)
- `codemodel-v2-5ca53682ca9cdbe188f5.json` (~207 tok)
- `directory-.-Debug-f5ebdc15457944623624.json` (~44 tok)
- `index-2026-05-05T12-08-27-0044.json` (~448 tok)

## mobile/android/app/.cxx/Debug/27596y4e/armeabi-v7a/CMakeFiles/

- `cmake.check_cache` — This file is generated by cmake for dependency checking of the CMakeCache.txt file (~23 tok)
- `CMakeOutput.log` (~12301 tok)
- `rules.ninja` — CMAKE generated file: DO NOT EDIT! (~405 tok)
- `TargetDirectories.txt` (~55 tok)

## mobile/android/app/.cxx/Debug/27596y4e/armeabi-v7a/CMakeFiles/3.22.1-g37088a8/

- `CMakeCCompiler.cmake` (~919 tok)
- `CMakeCXXCompiler.cmake` (~1772 tok)
- `CMakeSystem.cmake` (~123 tok)

## mobile/android/app/.cxx/Debug/27596y4e/armeabi-v7a/CMakeFiles/3.22.1-g37088a8/CompilerIdC/

- `CMakeCCompilerId.c` — ifdef __cplusplus (~7101 tok)
- `CMakeCCompilerId.o` (~1106 tok)

## mobile/android/app/.cxx/Debug/27596y4e/armeabi-v7a/CMakeFiles/3.22.1-g37088a8/CompilerIdCXX/

- `CMakeCXXCompilerId.cpp` (~7028 tok)
- `CMakeCXXCompilerId.o` (~1115 tok)

## mobile/android/app/.cxx/Debug/27596y4e/x86/

- `additional_project_files.txt` (~0 tok)
- `android_gradle_build_mini.json` (~166 tok)
- `android_gradle_build.json` (~267 tok)
- `build_file_index.txt` (~25 tok)
- `build.ninja` — CMAKE generated file: DO NOT EDIT! (~6177 tok)
- `cmake_install.cmake` — Install script for directory: /home/beou/snap/flutter/common/flutter/packages/flutter_tools/gradle/src/main/groovy (~483 tok)
- `CMakeCache.txt` — This is the CMakeCache file. (~4114 tok)
- `metadata_generation_command.txt` (~256 tok)
- `prefab_config.json` (~12 tok)
- `symbol_folder_index.txt` (~22 tok)

## mobile/android/app/.cxx/Debug/27596y4e/x86/.cmake/api/v1/query/client-agp/

- `cache-v2` (~0 tok)
- `cmakeFiles-v1` (~0 tok)
- `codemodel-v2` (~0 tok)

## mobile/android/app/.cxx/Debug/27596y4e/x86/.cmake/api/v1/reply/

- `cache-v2-db52427d632a4878ef55.json` — Declares of (~7750 tok)
- `cmakeFiles-v1-503880802d6b9bc4fe00.json` (~7498 tok)
- `codemodel-v2-5ddcac7a0f8dc3c1d9a1.json` (~205 tok)
- `directory-.-Debug-f5ebdc15457944623624.json` (~44 tok)
- `index-2026-05-05T12-08-27-0346.json` (~448 tok)

## mobile/android/app/.cxx/Debug/27596y4e/x86/CMakeFiles/

- `cmake.check_cache` — This file is generated by cmake for dependency checking of the CMakeCache.txt file (~23 tok)
- `CMakeOutput.log` (~11156 tok)
- `rules.ninja` — CMAKE generated file: DO NOT EDIT! (~403 tok)
- `TargetDirectories.txt` (~51 tok)

## mobile/android/app/.cxx/Debug/27596y4e/x86/CMakeFiles/3.22.1-g37088a8/

- `CMakeCCompiler.cmake` (~917 tok)
- `CMakeCXXCompiler.cmake` (~1770 tok)
- `CMakeSystem.cmake` (~123 tok)

## mobile/android/app/.cxx/Debug/27596y4e/x86/CMakeFiles/3.22.1-g37088a8/CompilerIdC/

- `CMakeCCompilerId.c` — ifdef __cplusplus (~7101 tok)
- `CMakeCCompilerId.o` (~1048 tok)

## mobile/android/app/.cxx/Debug/27596y4e/x86/CMakeFiles/3.22.1-g37088a8/CompilerIdCXX/

- `CMakeCXXCompilerId.cpp` (~7028 tok)
- `CMakeCXXCompilerId.o` (~1056 tok)

## mobile/android/app/.cxx/Debug/27596y4e/x86_64/

- `additional_project_files.txt` (~0 tok)
- `android_gradle_build_mini.json` (~168 tok)
- `android_gradle_build.json` (~269 tok)
- `build_file_index.txt` (~25 tok)
- `build.ninja` — CMAKE generated file: DO NOT EDIT! (~6181 tok)
- `cmake_install.cmake` — Install script for directory: /home/beou/snap/flutter/common/flutter/packages/flutter_tools/gradle/src/main/groovy (~484 tok)

## mobile/android/app/.cxx/Debug/27596y4e/x86_64/.cmake/api/v1/query/client-agp/

- `cache-v2` (~0 tok)
- `cmakeFiles-v1` (~0 tok)
- `codemodel-v2` (~0 tok)

## mobile/android/app/.cxx/Debug/27596y4e/x86_64/.cmake/api/v1/reply/

- `cache-v2-a7303108bf22db3f8e99.json` — Declares of (~7755 tok)
- `cmakeFiles-v1-57baa713cd081210ab21.json` (~7504 tok)
- `codemodel-v2-f794c631d6ce7f664834.json` (~206 tok)
