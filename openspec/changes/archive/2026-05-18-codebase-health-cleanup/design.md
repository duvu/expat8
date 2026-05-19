## Context

The expat8 codebase spans three layers (backend Node.js, mobile Flutter, Next.js dashboard) with 319 passing tests and a minimal dependency footprint. Through organic growth, several files have exceeded maintainable sizes, utility functions are duplicated across module boundaries, dead code lingers, and admin API endpoints used by the dashboard lack documentation. No linting or formatting tools exist for the backend despite 9,000+ lines of source code.

Current state:
- `backend/src/app.js` (1233 lines): 35+ route handlers monolithically defined
- `backend/src/word_store.js` (2814 lines): store logic + 1200 lines of seed data + exam helpers
- `backend/src/routes/exam.js`: copies 3 utilities from app.js instead of importing them
- `mobile/lib/src/api/backend_api_client.dart` (2059 lines): 20+ endpoints + 15 DTOs inline
- `express-rate-limit` in package.json but never imported
- `http_utils.js` has zero imports anywhere
- `contracts/api.md` documents mobile endpoints but not 7+ admin endpoints

## Goals / Non-Goals

**Goals:**
- Eliminate all dead code and phantom dependencies
- Extract duplicated utilities into shared modules (single source of truth)
- Split monolithic files into domain-oriented modules without changing behavior
- Add ESLint + Prettier for consistent backend code style
- Document all admin API endpoints in contracts/api.md
- Archive fully-completed OpenSpec changes

**Non-Goals:**
- Changing any business logic or API behavior
- Adopting a DI framework or state management library (Provider/Riverpod) for mobile
- Adding authentication to the dashboard
- Migrating test frameworks or adding coverage tooling
- Refactoring mobile controller patterns (ChangeNotifier → BLoC)
- Addressing the dashboard's dual-access pattern (direct DB + API)

## Decisions

### D1: Backend route extraction strategy

**Decision**: Extract routes into `src/routes/<domain>.js` files, each exporting a factory function that receives dependencies (store, config, logger).

**Rationale**: Follows the existing pattern in `routes/exam.js` but without the duplication. Each route file imports shared utilities from a new `src/routes/helpers.js`. The app.js file becomes a thin orchestrator that wires route modules.

**Alternatives considered**:
- Express sub-apps: Over-engineered for this size
- Class-based controllers: Doesn't match the existing functional style
- Keep monolithic but add regions/comments: Doesn't fix merge conflict risk

**Route modules**: `auth.js`, `admin.js`, `learning.js`, `articles.js`, `speaking.js`, `proficiency.js`, `study-events.js`, `content-packs.js`, `user.js`

### D2: Shared utilities extraction

**Decision**: Create `src/routes/helpers.js` exporting `asyncHandler`, `bearerToken`, `resolveRequiredUserSession`, `resolveOptionalUserSession`. Create `src/store_utils.js` exporting `statusForRating`, `nextReviewForRating`, `normalizeWeekStart`.

**Rationale**: These functions are currently duplicated verbatim. Centralizing them means bug fixes propagate automatically. Route helpers go in `routes/` because they depend on Express request/response types. Store utils go in `src/` because they're pure functions used by both store implementations.

### D3: Seed data extraction from word_store.js

**Decision**: Move the ~1200 lines of hard-coded vocabulary seed data into `src/seed_data.js` (exported as a constant). `WordStore` imports it during initialization.

**Rationale**: Seed data is configuration, not logic. Separating it makes word_store.js focus on behavior and reduces its line count by ~40%.

### D4: Mobile API client refactoring

**Decision**: Extract DTOs into `lib/src/api/models/` directory (one file per response group). Extract a private `_request()` helper method within BackendApiClient that encapsulates the repeated stopwatch + timeout + logging pattern.

**Rationale**: DTOs are data definitions that change independently from the HTTP transport logic. The `_request()` helper eliminates ~500 lines of repetitive boilerplate while keeping the signing logic in one place.

**File structure**:
```
lib/src/api/
  backend_api_client.dart    (transport + signing + _request helper)
  models/
    learning_models.dart     (LearningCardBatch, SyncResult, etc.)
    exam_models.dart         (ExamSessionResponse, ExamQuestion, etc.)
    content_models.dart      (ContentPack, ContentPackSummary, etc.)
    speaking_models.dart     (SpeakingWeeklySummary, SpeakingPromptItem)
    user_models.dart         (UserSession-related DTOs)
```

### D5: ESLint + Prettier configuration

**Decision**: Add as devDependencies with a minimal, non-disruptive baseline configuration. Use `eslint.config.js` (flat config, ESLint 9+). Prettier defaults with single quotes to match existing style. Add `lint` and `format` scripts to package.json.

**Rationale**: Zero devDependencies is admirable for minimalism but harmful for collaboration and consistency. Starting with a permissive config avoids a massive initial diff while establishing the tooling foundation.

**No auto-fix on save mandated** — this is a CI/script concern, not an editor mandate.

### D6: Admin API documentation approach

**Decision**: Add admin endpoint sections to the existing `contracts/api.md` file under a new `## Admin Endpoints` heading, following the same format used for existing endpoints.

**Rationale**: Single source of truth. The existing document format (endpoint, request/response examples, error codes) is well-established. Admin endpoints follow the same auth model (app credentials + admin token) so they belong in the same document.

### D7: Dead code and phantom dependency removal

**Decision**: Delete `src/http_utils.js`, remove `express-rate-limit` from package.json, remove `telemetry.dart` DebugTelemetrySink (keep the abstract class and event enum as they define the interface for future real implementations).

**Rationale**: Dead code misleads readers and creates false dependencies. The rate limit implementation is custom and works; the phantom package adds confusion about what's actually used.

## Risks / Trade-offs

- **[Risk] Large number of file moves/renames** → Mitigate by doing route extraction in a single atomic step with all tests passing before and after. Git handles renames well.
- **[Risk] Import path changes break something** → Mitigate by running full test suite after each extraction phase. No behavioral change means tests are the safety net.
- **[Risk] ESLint reports hundreds of issues on first run** → Mitigate by using a permissive baseline config (no style rules that conflict with existing patterns). Fix only errors, not warnings, in this change.
- **[Risk] Mobile DTO extraction breaks imports in tests** → Mitigate by using barrel exports (re-export from api_client.dart) so existing import paths continue to work, with deprecation comments pointing to new locations.
- **[Trade-off] Route files add indirection** → Acceptable: finding a handler by endpoint path is straightforward with file-per-domain naming.
- **[Trade-off] Adding devDependencies increases install size** → Minimal impact: ESLint + Prettier are dev-only, never deployed.
