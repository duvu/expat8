# Cerebrum

> OpenWolf's learning memory. Updated automatically as the AI learns from interactions.
> Do not edit manually unless correcting an error.
> Last updated: 2026-05-09

## User Preferences

<!-- How the user likes things done. Code style, tools, patterns, communication. -->

## Key Learnings

- **Practice games must not use the card-flow `easy` rating path**: it deletes the word locally. Use `WordRepository.recordPracticeAnswer`. Game-sourced study events (`source` starting `game_`) never move proficiency (the ladder downgrades on 5× `hard`).
- **Flame widget tests**: tap by canvas coordinates, advance with timed `pump`, never `pumpAndSettle` while a game loop runs; widget-test HTTP returns 400 for every request, so fake offline APIs must throw instead.

- **Production backend sits behind a reverse proxy** (expat8.x51.vn → Z440 port 18787); IP-based limits need `TRUST_PROXY` set to the proxy address. Z440 Caddyfile does not route expat8 — the proxy is upstream/elsewhere.
- **Auth rate limiting:** `authIpLimiter` (per IP, shared) runs before per `ip|identifier` limiters in `routes/auth.js`.

- **Root `openspec/` is gitignored and absent locally**; only `backend/openspec/changes/` is tracked. Roadmap references to `openspec/changes/*` cannot be verified from the repo.
- **Dashboard reads PostgreSQL directly** (`expat8-dashboard/src/lib/db.ts`, `analytics.ts`) in addition to signed backend API calls.

- **Project:** expat8
- **Description:** This workspace contains the OpenSpec-driven MVP implementation for a Flutter vocabulary learning app and a lightweight backend service.
- **Repo guidance:** `backend/` is Node.js 22 + Express, `mobile/` is Flutter, `contracts/api.md` is the API source of truth, and `docker-compose.yml` starts PostgreSQL + backend locally.
- **Host mapping:** `<INTERNAL_HOST>` is the local machine for this workspace, so deploy commands targeting that IP are effectively local-host operations here.

## User Preferences

- [2026-09-28] User removed PR CI (GitHub Actions checks too slow). Do not re-add CI workflows; run checks locally. Keep android-release.yml (signing secrets).
- User writes in Vietnamese (no diacritics); reply and write review docs in Vietnamese.
- Goal (2026-09-28): production-grade, high-quality product.
- Keep root repo instructions compact and only include high-signal, repo-specific facts.

## Do-Not-Repeat

- [2026-09-28] Flutter 3.47.5 needs Gradle ≥ 8.14, AGP ≥ 8.11.1, Kotlin ≥ 2.2.20; objectbox_flutter_libs declares compileSdk 31 → root build.gradle.kts raises library plugins to 36. CI was removed on 2026-09-28 (user: checks too slow), so a failing Android build only shows up in the tag-triggered release workflow.
- [2026-09-28] Release signing secrets exist only in GitHub Actions; build releases by pushing tag `v<pubspec version>` (Android Release workflow), not locally.

<!-- Mistakes made and corrected. Each entry prevents the same mistake recurring. -->
<!-- Format: [YYYY-MM-DD] Description of what went wrong and what to do instead. -->
- [2026-09-28] `crypto.promises` does not exist in Node — use `util.promisify(crypto.scrypt)` for async scrypt.
- [2026-09-28] `flutter test` on the local Flutter 3.47.5 rewrites `mobile/pubspec.lock` and `analysis_options.yaml`; revert them after running if not intended. Flutter version is not pinned.

## Decision Log

<!-- Significant technical decisions with rationale. Why X was chosen over Y. -->
