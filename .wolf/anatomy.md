# anatomy.md

> Auto-maintained by OpenWolf. Last scanned: 2026-05-09T06:53:31.535Z
> Files: 540 tracked | Anatomy hits: 0 | Misses: 0

## ./

- `.gitignore` — Git ignore rules (~27 tok)
- `AGENTS.md` — AGENTS.md (~513 tok)
- `CLAUDE.md` — OpenWolf (~1610 tok)
- `docker-compose.yml` — Docker Compose services (~568 tok)
- `README.md` — Project documentation (~723 tok)

## .claude/

- `settings.json` (~441 tok)
- `settings.local.json` (~29 tok)

## .claude/rules/

- `openwolf.md` (~313 tok)

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

## .serena/

- `.gitignore` — Git ignore rules (~7 tok)
- `project.local.yml` — This file allows you to locally override settings in project.yml for development purposes. (~115 tok)
- `project.yml` — the name by which the project can be referenced within Serena (~2661 tok)

## backend/

- `.dockerignore` — Docker ignore rules (~21 tok)
- `Dockerfile` — Docker container definition (~45 tok)
- `package-lock.json` — npm lock file (~9990 tok)
- `package.json` — Node.js package manifest (~129 tok)
- `README.md` — Project documentation (~239 tok)

## backend/db/

- `schema.sql` — Database schema (~1223 tok)

## backend/db/migrations/

- `20260504_add_adaptive_proficiency_system.sql` — SQL: tables: user_proficiency (~102 tok)
- `20260504_add_user_identity.sql` — SQL: tables: users, user_sessions, 1 alter(s) (~279 tok)
- `20260505_backend_managed_vocabulary_pool.sql` — SQL: tables: generation_runs, scheduler_locks, user_cached_words, 4 alter(s) (~534 tok)
- `20260506_backfill_user_state_unique_indexes.sql` (~568 tok)
- `20260506_language_native_proficiency_scale.sql` — SQL: 6 alter(s) (~286 tok)
- `20260506_user_proficiency_owner_indexes.sql` — SQL: 1 alter(s) (~358 tok)
- `20260507_fix_codebase_review_issues.sql` — Migration: fix-codebase-review-issues (~58 tok)
- `20260509_content_ingestion_v2_foundation.sql` — Migration: content-ingestion-v2-foundation (~1246 tok)

## backend/scripts/

- `verify_content_ingestion_migration.mjs` — REQUIRED_TABLES: main, findMissingTables, findMissingIndexes (~578 tok)

## backend/src/

- `app_credentials.js` — Exports InMemoryNonceCache, canonicalPathWithSortedQuery, hashBody, buildCanonicalRequest + 2 more (~1119 tok)
- `app.js` — API routes: GET, POST, DELETE (18 endpoints) (~7746 tok)
- `article_processing_pipeline.js` — Exports ArticleProcessingPipeline (~672 tok)
- `article_processing_worker.js` — Exports ArticleProcessingWorker (~624 tok)
- `article_term_extractor.js` — Exports extractCandidateTerms (~384 tok)
- `config.js` — Exports loadConfig (~1058 tok)
- `database.js` — Exports readSchemaSql, initializeDatabaseSchema (~142 tok)
- `generation_service.js` — Exports VocabularyGenerationService, parseVocabularyJson (~892 tok)
- `http_utils.js` — Exports readJson, sendJson (~117 tok)
- `ids.js` — Exports createId (~34 tok)
- `litellm_client.js` — Exports LiteLLMClient (~1426 tok)
- `logger.js` — Exports createLogger, sanitizeFields (~987 tok)
- `normalize.js` — Exports normalizeTerm (~32 tok)
- `postgres_word_store.js` — Exports PostgresWordStore (~12368 tok)
- `proficiency.js` — Exports CEFR_LEVELS, HSK_LEVELS, DEFAULT_PROFICIENCY_LEVEL, VALID_STUDY_RATINGS + 16 more (~1416 tok)
- `runtime.js` — Exports createStore, createBackendRuntime (~664 tok)
- `server.js` (~148 tok)
- `user_identity.js` — Exports DuplicateUserError, InvalidCredentialsError, InvalidRegistrationInputError, normalizeUserIdentifier + 5 more (~618 tok)
- `vocabulary_enrichment_adapter.js` — Exports VocabularyEnrichmentAdapter (~900 tok)
- `vocabulary_pool_scheduler.js` — Exports VocabularyPoolScheduler (~1207 tok)
- `vocabulary_validator.js` — Exports validateVocabularyItem (~424 tok)
- `word_store.js` — Exports WordStore (~9001 tok)
- `worker.js` — config: tick (~472 tok)

## backend/test/

- `api_logging.test.js` — lines: listen (~757 tok)
- `api.test.js` — Declares store (~9833 tok)
- `app_credentials.test.js` — activeCredential: signedHeaders (~1406 tok)
- `article_processing_worker.test.js` — Declares store (~1055 tok)
- `config.test.js` — Declares config (~720 tok)
- `database.test.js` — Declares schemaSql (~236 tok)
- `e2e_prod_test.mjs` — E2E test against production backend at https://expat8.x51.vn (~4170 tok)
- `e2e_smoke.test.js` — backendStore: listen, fetchJson, wordInput (~2597 tok)
- `generation_service.test.js` — items: wordInput (~1764 tok)
- `litellm_client.test.js` — Declares client (~571 tok)
- `logger.test.js` — Declares chunks (~484 tok)
- `postgres_integration.test.js` — testDatabaseUrl: resetSchema, listen, fetchJson, wordInput (~1243 tok)
- `postgres_word_store.test.js` — Declares store (~6198 tok)
- `proficiency.test.js` (~574 tok)
- `runtime.test.js` — Declares store (~264 tok)
- `user_identity.test.js` (~112 tok)
- `vocabulary_pool_scheduler.test.js` — store: schedulerConfig, wordInput (~798 tok)
- `vocabulary_validator.test.js` — Declares wordInput (~428 tok)
- `word_store.test.js` — store: wordInput (~3184 tok)

## backend/test/support/

- `app_credential_helpers.js` — Exports testAppCredential, loadTestConfig, signedFetchOptions (~466 tok)

## contracts/

- `api.md` — API Contracts (~2394 tok)

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
- `app-credential-security.md` — App Credential Security (~3196 tok)
- `architecture.md` — Kiến trúc hệ thống Expat8 — Version 2 (~7138 tok)
- `chinese-language-e2e-investigation.md` — Investigation: Tiếng Trung E2E Flow (~2188 tok)
- `expat8_logs_2026_05_07T16_39_51_937450Z_1.txt` — Expat8 mobile logs (~3682 tok)
- `mobile-system-logging.md` — Mobile System Logging (~670 tok)
- `mvp-setup.md` — MVP Setup and Limitations (~2300 tok)
- `random-fallback-investigation.md` — Investigation: "Rất ít từ vựng sẵn sàng" khi mở app (~987 tok)
- `release-notes.md` — Release Notes (~537 tok)
- `seed-vocabulary.md` — Seed Vocabulary Bundling (~1193 tok)

## mobile/

- `.flutter-plugins` — This is a generated file; do not edit or check into version control. (~241 tok)
- `.flutter-plugins-dependencies` (~1098 tok)
- `.gitignore` — Git ignore rules (~190 tok)
- `.metadata` — This file tracks properties of this Flutter project. (~455 tok)
- `analysis_options.yaml` (~27 tok)
- `expat8_language_app.iml` (~225 tok)
- `pubspec.yaml` — Dart/Flutter package manifest (~185 tok)
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

- `package_config_subset` — Declares 3 (~3798 tok)
- `package_config.json` (~5107 tok)
- `version` (~2 tok)

## mobile/.dart_tool/dartpad/

- `web_plugin_registrant.dart` — Flutter web plugin registrant file. (~149 tok)

## mobile/.dart_tool/flutter_build/

- `dart_plugin_registrant.dart` — This file is generated from template in file `flutter_tools/lib/src/flutter_plugins.dart`. (~919 tok)

## mobile/.dart_tool/flutter_build/3890bae01864a2cebde7afaf35563c13/

- `_composite.stamp` (~7 tok)
- `.filecache` (~39405 tok)
- `android_aot_bundle_release_android-arm.stamp` (~64 tok)
- `android_aot_bundle_release_android-arm64.stamp` (~63 tok)
- `android_aot_bundle_release_android-x64.stamp` (~62 tok)
- `android_aot_release_android-arm.stamp` (~150 tok)
- `android_aot_release_android-arm64.stamp` (~150 tok)
- `android_aot_release_android-x64.stamp` (~149 tok)
- `aot_android_asset_bundle.stamp` (~1894 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `flutter_android_aot_bundle_release_android-arm.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-x64.d` (~1 tok)
- `flutter_android_aot_release_android-arm.d` (~1 tok)
- `flutter_android_aot_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_release_android-x64.d` (~1 tok)
- `flutter_assets.d` (~1741 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~22484 tok)
- `kernel_snapshot_program.stamp` (~23141 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~316 tok)

## mobile/.dart_tool/flutter_build/63c1ecaa6bef3e93c090e5a2945ced77/

- `.filecache` (~39236 tok)
- `android_aot_bundle_release_android-x64.stamp` (~62 tok)
- `android_aot_release_android-x64.stamp` (~149 tok)
- `aot_android_asset_bundle.stamp` (~1894 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `flutter_android_aot_bundle_release_android-x64.d` (~1 tok)
- `flutter_android_aot_release_android-x64.d` (~1 tok)
- `flutter_assets.d` (~1741 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~22484 tok)
- `kernel_snapshot_program.stamp` (~23141 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~260 tok)

## mobile/.dart_tool/flutter_build/7414d1c782ffa3d28ec293de3b1e6e4a/

- `.filecache` (~39238 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `debug_android_application.stamp` (~2016 tok)
- `flutter_assets.d` (~1738 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~22484 tok)
- `kernel_snapshot_program.stamp` (~23141 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~324 tok)

## mobile/.dart_tool/flutter_build/8edc2907814c450acf045e762da8abac/

- `.filecache` (~39238 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `debug_android_application.stamp` (~2016 tok)
- `flutter_assets.d` (~1738 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~22484 tok)
- `kernel_snapshot_program.stamp` (~23141 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~324 tok)

## mobile/.dart_tool/flutter_build/97f29be706d3822f2d856b92e41c9ca2/

- `.filecache` (~39238 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `debug_android_application.stamp` (~2016 tok)
- `flutter_assets.d` (~1738 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~22484 tok)
- `kernel_snapshot_program.stamp` (~23141 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~324 tok)

## mobile/.dart_tool/flutter_build/e6b60fcd623eab66cfaafe1a51316e44/

- `_composite.stamp` (~7 tok)
- `.filecache` (~52508 tok)
- `android_aot_bundle_release_android-arm.stamp` (~64 tok)
- `android_aot_bundle_release_android-arm64.stamp` (~63 tok)
- `android_aot_bundle_release_android-x64.stamp` (~62 tok)
- `android_aot_release_android-arm.stamp` (~150 tok)
- `android_aot_release_android-arm64.stamp` (~150 tok)
- `android_aot_release_android-x64.stamp` (~149 tok)
- `aot_android_asset_bundle.stamp` (~2051 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `flutter_android_aot_bundle_release_android-arm.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-x64.d` (~1 tok)
- `flutter_android_aot_release_android-arm.d` (~1 tok)
- `flutter_android_aot_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_release_android-x64.d` (~1 tok)
- `flutter_assets.d` (~1894 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~30954 tok)
- `kernel_snapshot_program.stamp` (~31777 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~316 tok)

## mobile/.dart_tool/flutter_build/feb2f34a12b0151fe1fe42c88a188cd2/

- `_composite.stamp` (~7 tok)
- `.filecache` (~51399 tok)
- `android_aot_bundle_release_android-arm.stamp` (~64 tok)
- `android_aot_bundle_release_android-arm64.stamp` (~63 tok)
- `android_aot_bundle_release_android-x64.stamp` (~62 tok)
- `android_aot_release_android-arm.stamp` (~150 tok)
- `android_aot_release_android-arm64.stamp` (~150 tok)
- `android_aot_release_android-x64.stamp` (~149 tok)
- `aot_android_asset_bundle.stamp` (~2196 tok)
- `dart_build_result.json` (~11 tok)
- `dart_build.d` (~33 tok)
- `dart_build.stamp` (~121 tok)
- `flutter_android_aot_bundle_release_android-arm.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_bundle_release_android-x64.d` (~1 tok)
- `flutter_android_aot_release_android-arm.d` (~1 tok)
- `flutter_android_aot_release_android-arm64.d` (~1 tok)
- `flutter_android_aot_release_android-x64.d` (~1 tok)
- `flutter_assets.d` (~2036 tok)
- `gen_dart_plugin_registrant.stamp` (~51 tok)
- `gen_localizations.stamp` (~7 tok)
- `install_code_assets.d` (~32 tok)
- `install_code_assets.stamp` (~119 tok)
- `kernel_snapshot_program.d` (~29604 tok)
- `kernel_snapshot_program.stamp` (~30427 tok)
- `native_assets.json` (~13 tok)
- `outputs.json` (~420 tok)

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

## mobile/android/.gradle/vcs-1/

- `gc.properties` (~0 tok)

## mobile/android/app/

- `build.gradle.kts` — Gradle Kotlin build configuration (~376 tok)

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
- `CMakeCache.txt` — This is the CMakeCache file. (~4119 tok)
- `metadata_generation_command.txt` (~260 tok)
- `prefab_config.json` (~12 tok)
- `symbol_folder_index.txt` (~23 tok)

## mobile/android/app/.cxx/Debug/27596y4e/x86_64/.cmake/api/v1/query/client-agp/

- `cache-v2` (~0 tok)
- `cmakeFiles-v1` (~0 tok)
- `codemodel-v2` (~0 tok)

## mobile/android/app/.cxx/Debug/27596y4e/x86_64/.cmake/api/v1/reply/

- `cache-v2-a7303108bf22db3f8e99.json` — Declares of (~7755 tok)
- `cmakeFiles-v1-57baa713cd081210ab21.json` (~7504 tok)
- `codemodel-v2-f794c631d6ce7f664834.json` (~206 tok)
- `directory-.-Debug-f5ebdc15457944623624.json` (~44 tok)
- `index-2026-05-05T12-08-27-0623.json` (~448 tok)

## mobile/android/app/.cxx/Debug/27596y4e/x86_64/CMakeFiles/

- `cmake.check_cache` — This file is generated by cmake for dependency checking of the CMakeCache.txt file (~23 tok)
- `CMakeOutput.log` (~12030 tok)
- `rules.ninja` — CMAKE generated file: DO NOT EDIT! (~404 tok)
- `TargetDirectories.txt` (~53 tok)

## mobile/android/app/.cxx/Debug/27596y4e/x86_64/CMakeFiles/3.22.1-g37088a8/

- `CMakeCCompiler.cmake` (~974 tok)
- `CMakeCXXCompiler.cmake` (~1827 tok)
- `CMakeSystem.cmake` (~123 tok)

## mobile/android/app/.cxx/Debug/27596y4e/x86_64/CMakeFiles/3.22.1-g37088a8/CompilerIdC/

- `CMakeCCompilerId.c` — ifdef __cplusplus (~7101 tok)
- `CMakeCCompilerId.o` (~1443 tok)

## mobile/android/app/.cxx/Debug/27596y4e/x86_64/CMakeFiles/3.22.1-g37088a8/CompilerIdCXX/

- `CMakeCXXCompilerId.cpp` (~7028 tok)
- `CMakeCXXCompilerId.o` (~1458 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/

- `hash_key.txt` — Values used to calculate the hash in this folder name. (~308 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/arm64-v8a/

- `additional_project_files.txt` (~0 tok)
- `android_gradle_build_mini.json` (~170 tok)
- `android_gradle_build.json` (~271 tok)
- `build_file_index.txt` (~25 tok)
- `build.ninja` — CMAKE generated file: DO NOT EDIT! (~6219 tok)
- `cmake_install.cmake` — Install script for directory: /home/beou/snap/flutter/common/flutter/packages/flutter_tools/gradle/src/main/groovy (~485 tok)
- `CMakeCache.txt` — This is the CMakeCache file. (~4143 tok)
- `metadata_generation_command.txt` (~264 tok)
- `prefab_config.json` (~12 tok)
- `symbol_folder_index.txt` (~24 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/arm64-v8a/.cmake/api/v1/query/client-agp/

- `cache-v2` (~0 tok)
- `cmakeFiles-v1` (~0 tok)
- `codemodel-v2` (~0 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/arm64-v8a/.cmake/api/v1/reply/

- `cache-v2-fdeddc750bf2dd950189.json` — Declares of (~7781 tok)
- `cmakeFiles-v1-a90e45e267848e3e2eca.json` (~7540 tok)
- `codemodel-v2-9c25d319424d8a6742e6.json` (~207 tok)
- `directory-.-Debug-f5ebdc15457944623624.json` (~44 tok)
- `index-2026-05-06T13-40-05-0725.json` (~448 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/arm64-v8a/CMakeFiles/

- `cmake.check_cache` — This file is generated by cmake for dependency checking of the CMakeCache.txt file (~23 tok)
- `CMakeOutput.log` (~11480 tok)
- `rules.ninja` — CMAKE generated file: DO NOT EDIT! (~404 tok)
- `TargetDirectories.txt` (~54 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/arm64-v8a/CMakeFiles/3.22.1-g37088a8/

- `CMakeCCompiler.cmake` (~920 tok)
- `CMakeCXXCompiler.cmake` (~1773 tok)
- `CMakeSystem.cmake` (~123 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/arm64-v8a/CMakeFiles/3.22.1-g37088a8/CompilerIdC/

- `CMakeCCompilerId.c` — ifdef __cplusplus (~7101 tok)
- `CMakeCCompilerId.o` (~1613 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/arm64-v8a/CMakeFiles/3.22.1-g37088a8/CompilerIdCXX/

- `CMakeCXXCompilerId.cpp` (~7028 tok)
- `CMakeCXXCompilerId.o` (~1615 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/armeabi-v7a/

- `additional_project_files.txt` (~0 tok)
- `android_gradle_build_mini.json` (~171 tok)
- `android_gradle_build.json` (~272 tok)
- `build_file_index.txt` (~25 tok)
- `build.ninja` — CMAKE generated file: DO NOT EDIT! (~6222 tok)
- `cmake_install.cmake` — Install script for directory: /home/beou/snap/flutter/common/flutter/packages/flutter_tools/gradle/src/main/groovy (~485 tok)
- `CMakeCache.txt` — This is the CMakeCache file. (~4146 tok)
- `metadata_generation_command.txt` (~266 tok)
- `prefab_config.json` (~12 tok)
- `symbol_folder_index.txt` (~24 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/armeabi-v7a/.cmake/api/v1/query/client-agp/

- `cache-v2` (~0 tok)
- `cmakeFiles-v1` (~0 tok)
- `codemodel-v2` (~0 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/armeabi-v7a/.cmake/api/v1/reply/

- `cache-v2-20b0d9f30737d123ca68.json` — Declares of (~7784 tok)
- `cmakeFiles-v1-472dd979af832b5ac82a.json` (~7544 tok)
- `codemodel-v2-33493940d7123aa0023d.json` (~207 tok)
- `directory-.-Debug-f5ebdc15457944623624.json` (~44 tok)
- `index-2026-05-06T13-40-06-0104.json` (~448 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/armeabi-v7a/CMakeFiles/

- `cmake.check_cache` — This file is generated by cmake for dependency checking of the CMakeCache.txt file (~23 tok)
- `CMakeOutput.log` (~12266 tok)
- `rules.ninja` — CMAKE generated file: DO NOT EDIT! (~405 tok)
- `TargetDirectories.txt` (~55 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/armeabi-v7a/CMakeFiles/3.22.1-g37088a8/

- `CMakeCCompiler.cmake` (~919 tok)
- `CMakeCXXCompiler.cmake` (~1772 tok)
- `CMakeSystem.cmake` (~123 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/armeabi-v7a/CMakeFiles/3.22.1-g37088a8/CompilerIdC/

- `CMakeCCompilerId.c` — ifdef __cplusplus (~7101 tok)
- `CMakeCCompilerId.o` (~1104 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/armeabi-v7a/CMakeFiles/3.22.1-g37088a8/CompilerIdCXX/

- `CMakeCXXCompilerId.cpp` (~7028 tok)
- `CMakeCXXCompilerId.o` (~1114 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/x86/

- `additional_project_files.txt` (~0 tok)
- `android_gradle_build_mini.json` (~166 tok)
- `android_gradle_build.json` (~267 tok)
- `build_file_index.txt` (~25 tok)
- `build.ninja` — CMAKE generated file: DO NOT EDIT! (~6211 tok)
- `cmake_install.cmake` — Install script for directory: /home/beou/snap/flutter/common/flutter/packages/flutter_tools/gradle/src/main/groovy (~483 tok)
- `CMakeCache.txt` — This is the CMakeCache file. (~4132 tok)
- `metadata_generation_command.txt` (~256 tok)
- `prefab_config.json` (~12 tok)
- `symbol_folder_index.txt` (~22 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/x86/.cmake/api/v1/query/client-agp/

- `cache-v2` (~0 tok)
- `cmakeFiles-v1` (~0 tok)
- `codemodel-v2` (~0 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/x86/.cmake/api/v1/reply/

- `cache-v2-c86f0bad380c22b585de.json` — Declares of (~7770 tok)
- `cmakeFiles-v1-139e6883f1ce30a06c82.json` (~7530 tok)
- `codemodel-v2-cf2c48e1ac49616a40be.json` (~205 tok)
- `directory-.-Debug-f5ebdc15457944623624.json` (~44 tok)
- `index-2026-05-06T13-40-06-0437.json` (~448 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/x86/CMakeFiles/

- `cmake.check_cache` — This file is generated by cmake for dependency checking of the CMakeCache.txt file (~23 tok)
- `CMakeOutput.log` (~11121 tok)
- `rules.ninja` — CMAKE generated file: DO NOT EDIT! (~403 tok)
- `TargetDirectories.txt` (~51 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/x86/CMakeFiles/3.22.1-g37088a8/

- `CMakeCCompiler.cmake` (~917 tok)
- `CMakeCXXCompiler.cmake` (~1770 tok)
- `CMakeSystem.cmake` (~123 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/x86/CMakeFiles/3.22.1-g37088a8/CompilerIdC/

- `CMakeCCompilerId.c` — ifdef __cplusplus (~7101 tok)
- `CMakeCCompilerId.o` (~1047 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/x86/CMakeFiles/3.22.1-g37088a8/CompilerIdCXX/

- `CMakeCXXCompilerId.cpp` (~7028 tok)
- `CMakeCXXCompilerId.o` (~1055 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/x86_64/

- `additional_project_files.txt` (~0 tok)
- `android_gradle_build_mini.json` (~168 tok)
- `android_gradle_build.json` (~269 tok)
- `build_file_index.txt` (~25 tok)
- `build.ninja` — CMAKE generated file: DO NOT EDIT! (~6215 tok)
- `cmake_install.cmake` — Install script for directory: /home/beou/snap/flutter/common/flutter/packages/flutter_tools/gradle/src/main/groovy (~484 tok)
- `CMakeCache.txt` — This is the CMakeCache file. (~4138 tok)
- `metadata_generation_command.txt` (~260 tok)
- `prefab_config.json` (~12 tok)
- `symbol_folder_index.txt` (~23 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/x86_64/.cmake/api/v1/query/client-agp/

- `cache-v2` (~0 tok)
- `cmakeFiles-v1` (~0 tok)
- `codemodel-v2` (~0 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/x86_64/.cmake/api/v1/reply/

- `cache-v2-f53919c5440044ad0f35.json` — Declares of (~7776 tok)
- `cmakeFiles-v1-aebeb5599f08de56afef.json` (~7535 tok)
- `codemodel-v2-b2a25f546464a99b9944.json` (~206 tok)
- `directory-.-Debug-f5ebdc15457944623624.json` (~44 tok)
- `index-2026-05-06T13-40-06-0717.json` (~448 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/x86_64/CMakeFiles/

- `cmake.check_cache` — This file is generated by cmake for dependency checking of the CMakeCache.txt file (~23 tok)
- `CMakeOutput.log` (~11995 tok)
- `rules.ninja` — CMAKE generated file: DO NOT EDIT! (~404 tok)

## mobile/android/app/.cxx/Debug/2h1sn5j6/x86_64/CMakeFiles/3.22.1-g37088a8/

- `CMakeCCompiler.cmake` (~974 tok)
- `CMakeCXXCompiler.cmake` (~1827 tok)
- `CMakeSystem.cmake` (~123 tok)

## mobile/lib/src/

- `config.dart` — Class: AppConfig (~450 tok)

## mobile/lib/src/data/

- `word_repository.dart` — Class: WordRepository (~5525 tok)

## mobile/lib/src/session/

- `learning_session_controller.dart` — Class: LearningSessionController (~7000 tok)

## mobile/test/

- `learning_session_controller_test.dart` — Declares Duration (~5631 tok)

## openspec/changes/missing-api-endpoints/

- `design.md` — Context (~1161 tok)
- `proposal.md` — Why (~590 tok)
- `tasks.md` — 1. Store methods (~813 tok)

## openspec/changes/missing-api-endpoints/specs/article-admin-update/

- `spec.md` — ADDED Requirements (~402 tok)

## openspec/changes/missing-api-endpoints/specs/article-deletion/

- `spec.md` — ADDED Requirements (~342 tok)

## openspec/changes/missing-api-endpoints/specs/article-vocabulary/

- `spec.md` — ADDED Requirements (~471 tok)

## openspec/changes/missing-api-endpoints/specs/backend-readiness-probe/

- `spec.md` — ADDED Requirements (~260 tok)

## openspec/changes/missing-api-endpoints/specs/study-events-api/

- `spec.md` — MODIFIED Requirements (~424 tok)

## openspec/changes/missing-api-endpoints/specs/user-profile/

- `spec.md` — ADDED Requirements (~215 tok)

## openspec/changes/mobile-local-first-card-selection/

- `.openspec.yaml` (~12 tok)
- `design.md` — Context (~1074 tok)
- `proposal.md` — Why (~595 tok)
- `tasks.md` — 1. Simplify refill trigger condition (~521 tok)

## openspec/changes/mobile-local-first-card-selection/specs/mobile-learning-session/

- `spec.md` — MODIFIED Requirements (~544 tok)

## openspec/changes/mobile-local-first-card-selection/specs/mobile-local-cache-sync/

- `spec.md` — MODIFIED Requirements (~647 tok)

## openspec/specs/mobile-learning-session/

- `spec.md` — Purpose (~1334 tok)

## openspec/specs/mobile-local-cache-sync/

- `spec.md` — ADDED Requirements (~1318 tok)
