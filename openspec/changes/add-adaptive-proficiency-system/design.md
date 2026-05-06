## Context

> Current-state note (2026-05-06): this design was written before user
> sessions, ObjectBox storage, and backend-owned learning-card selection were
> reconciled. Treat SQL/API examples for `/v1/words/next` as historical.
> Current card loading uses `POST /v1/learning/cards`; proficiency state is
> applied through that selection path.

The app currently has no proficiency system. Users see words with a `difficulty` field (currently free-form strings like `beginner`, `B1`, `intermediate`) but cannot track their own level or filter content appropriately. Study events are recorded but contain no rating information. The CEFR framework (A1–C2) provides an industry-standard proficiency scale suitable for this purpose.

**Current state**:
- `study_events` table records time spent and words studied, but no difficulty feedback
- `words` table has free-form `difficulty` field (mixed conventions: `beginner`, `B1`, `intermediate`)
- Mobile app has no proficiency display or rating mechanism
- No relationship between learner proficiency and content difficulty

**Stakeholders**: Mobile learners (implicit), backend serving content, AI generation system (needs proficiency target).

## Goals / Non-Goals

**Goals**:

1. Auto-detect proficiency level (A1–C2) from consecutive study ratings, without user input
2. Display current proficiency level prominently in the mobile UI (top-right corner)
3. Filter word feed by proficiency level to ensure appropriate difficulty
4. Trigger automatic level changes: 5× "Too Easy" → level up, 5× "Hard" → level down
5. Record explicit difficulty ratings on study events to support proficiency updates and analytics

**Non-Goals**:

- User-configurable proficiency (system is automatic)
- Per-language proficiency tracking beyond English (English-only for MVP)
- Cross-device proficiency sync (per-device for MVP; future: per-user once authentication exists)
- Proficiency as a user preference or onboarding step (no choice, auto-detect)
- Content recommendation or curriculum sequencing (proficiency filters only, no AI ordering)

## Decisions

### Decision 1: Separate `user_proficiency` Table

**Choice**: Create a new `user_proficiency` table storing (device_id, language, level, created_at, updated_at) separately from `study_events`.

**Rationale**:
- **Normalization**: One proficiency record per device/language, not scattered across events
- **Query efficiency**: Fast lookup without scanning all events
- **Schema clarity**: Separates state (proficiency level) from events (study history)
- **Future-proof**: Can add fields like `streak_count`, `confidence_score` without polluting events table

**Alternatives considered**:
- Add `current_level` column to `study_events`: Creates redundancy and denormalization; inefficient for queries
- Store in `user_word_states`: Mixes word-specific state with user-level state; confusing schema
- Embed in mobile app state only: No persistence or sync; fragile

**Design**:
```sql
CREATE TABLE user_proficiency (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID NOT NULL UNIQUE,
  language VARCHAR(10) NOT NULL DEFAULT 'en',
  level VARCHAR(2) NOT NULL, -- A1, A2, B1, B2, C1, C2
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE (device_id, language)
);
```

### Decision 2: Consecutive Count Logic Recomputed on Each Submission

**Choice**: Do not store a running counter client-side or in a single column. Instead, query the last N events and count consecutive same ratings on each study-event submission.

**Rationale**:
- **Atomicity**: Avoids race conditions if multiple requests arrive out of order
- **Reliability**: No trust in client state or stale cache
- **Transactional safety**: Read + update can be wrapped in a DB transaction

**Alternatives considered**:
- Store `last_consecutive_count` in `user_proficiency`: Client can become out-of-sync with actual event history
- Maintain client-side counter: Mobile app could send counter value; backend doesn't verify; easily gamed or corrupted

**Implementation**:
```javascript
// Pseudo-code
async function submitStudyEvent(deviceId, wordId, rating) {
  const newEvent = await db.study_events.insert({ device_id: deviceId, word_id: wordId, rating, timestamp: now() });
  
  const recentEvents = await db.study_events
    .where({ device_id: deviceId })
    .orderBy('timestamp', 'DESC')
    .limit(10);
  
  let consecutiveCount = 0;
  for (const event of recentEvents) {
    if (event.rating === rating) consecutiveCount++;
    else break;
  }
  
  if (consecutiveCount === 5) {
    await updateProficiency(deviceId, rating);
  }
  
  return { success: true, proficiency: { level, changed: ... } };
}
```

### Decision 3: Consecutive Threshold = 5

**Choice**: Proficiency changes when user presses the same rating 5 times in a row.

**Rationale**:
- **Spaced repetition**: 5 data points provide reasonable confidence without requiring many interactions
- **Session length**: Typical mobile session is 5–10 words; threshold fits naturally
- **No ML required**: Simple counter, easy to implement and debug
- **Buffers noise**: Single bad day or mistake doesn't trigger level change

**Alternatives considered**:
- Threshold = 3: Too noisy; users level up/down frequently
- Threshold = 7+: Too conservative; slow progression
- Weighted scoring (e.g., 3× "Too Easy" = 1 level up): More complex; harder to explain to users

### Decision 4: No User Choice; Auto-Detect Only

**Choice**: Users do not manually select or adjust proficiency. System auto-detects and auto-adjusts.

**Rationale**:
- **Reduces friction**: No onboarding form; app starts immediately
- **More accurate**: Behavior is more honest than self-assessment
- **Adaptive**: System naturally responds to growth; users don't need to remember to unlock harder content
- **Less intimidating**: New learners don't self-label

**Alternatives considered**:
- User picks level at onboarding: More control but more friction; self-assessment inaccuracy
- Hybrid (user choice + auto-adjust): Feature creep; confusing if user and system disagree

### Decision 5: Proficiency Display in Top-Right Corner

**Choice**: Display current level in the app bar's top-right corner (not a separate widget or modal).

**Rationale**:
- **Non-intrusive**: Doesn't block vocabulary card or buttons
- **Always visible**: User can glance at level anytime
- **Conventional**: Standard location for status info in mobile apps
- **Immediate feedback**: Level change is visible after 5th rating

**Alternatives considered**:
- Bottom-right: Obscured by rating buttons
- Center above card: Competes with vocabulary display
- Modal notification only: Level change isn't discoverable unless user looks

### Decision 6: CEFR A1–C2 Canonical Levels with Difficulty Field Mapping

**Choice**: Store level as A1, A2, B1, B2, C1, C2 (canonical CEFR). Map legacy `difficulty` values (beginner, intermediate, advanced, etc.) to CEFR on read/ingest.

**Rationale**:
- **Standardized**: CEFR is industry-recognized; aligns with language education
- **Ordered**: A1 < A2 < B1 ... < C2 enables filtering and progression
- **Backward-compatible**: Legacy values aren't deleted; mapped without data loss

**Alternatives considered**:
- Keep free-form `difficulty` strings: Hard to order or filter consistently
- Store both `difficulty` and `level`: Redundancy; risk of drift; which is source of truth?
- Only CEFR, delete legacy values: Data loss; breaks existing word records

**Migration approach** (Phase 2):
- For each word with legacy `difficulty`, map to CEFR: `beginner` → A1, `intermediate` → B1, `advanced` → C1, etc.
- New words generated by LiteLLM must specify CEFR target level
- Validation at ingestion: Reject or auto-map any value outside A1–C2

### Decision 7: Per-Device Proficiency (MVP); Per-User Future

**Choice**: For MVP, store proficiency keyed by `device_id` (no authentication required). Future: migrate to per-user once authentication exists.

**Rationale**:
- **MVP simplicity**: No user accounts, no sync logic
- **Deployment velocity**: Can ship today without auth backend
- **Data isolation**: Device proficiency is independent; no cross-device confusion
- **Future path**: Once auth is added, can migrate to per-user and sync across devices

**Alternatives considered**:
- Per-user from the start: Requires auth system; delays MVP
- Per-user + per-device: Adds complexity; unclear which takes priority

### Decision 8: Gradient Transition After Level Change

**Choice**: After proficiency level increases, show 1–2 words from the adjacent lower level (confidence building) before filtering fully to new level.

**Rationale**:
- **Smooth progression**: Avoids sudden jump to much harder content
- **Confidence**: Learner builds momentum before facing true new-level difficulty
- **Reduces frustration**: Prevents oscillation (level up → too hard → level down)

**Alternatives considered**:
- Immediate filter to new level: Aggressive but may overwhelm; causes rapid regress
- No transition: Abrupt; bad user experience

**Implementation**:
- On level change, set a flag `grace_period_count = 2`
- Next 2 words: 50% old level + 50% new level
- After 2 words: Filter 100% to new level

## Risks / Trade-offs

### Risk 1: User "Games" System (Rapid Tapping)

**Risk**: User presses "Too Easy" 5 times quickly and levels up artificially.

**Mitigation**:
- Add telemetry: Flag submissions arriving < 5 seconds apart as suspicious
- Optional cooldown: Proficiency can only change once per session (configurable, e.g., 1 hour)
- Visibility: Show "4 / 5 Too Easy" progress bar so user knows threshold; makes gaming obvious

### Risk 2: Counter Logic Bugs from Network Retries

**Risk**: Duplicate events or out-of-order submissions cause counter to miscount.

**Mitigation**:
- Always recompute from DB (don't trust client state)
- Use idempotent submission: Mobile sends `event_id` hash; backend deduplicates
- Wrap read + update in transaction: Atomicity guardrails

### Risk 3: Rapid Level Oscillation

**Risk**: User levels up, encounters 5 hard words, levels down immediately (wasted effort).

**Mitigation**:
- Gradient transition (see Decision 8): Show easier words first after level change
- Telemetry: Monitor oscillation rate; if high, increase threshold to 7 or add cooldown
- Future: Confidence weighting (not MVP)

### Risk 4: Word Difficulty Not Properly Tagged

**Risk**: Not all words in DB have valid CEFR level; filtering breaks or returns no results.

**Mitigation**:
- Data migration (Phase 2): Audit and map all existing `difficulty` values to CEFR
- Validation at ingest: Reject or auto-map new words without valid level
- Default fallback: If user at B1 and no B1 words available, return A2 or B2 (expand search radius)

### Risk 5: Level Boundary Behavior Undefined

**Risk**: User at A1 presses "Hard" 5×. Does level stay A1 or drop to "Pre-A1"?

**Mitigation**:
- Define boundaries: A1 is minimum level; stays A1 even with 5 "Hard". C2 is maximum; stays C2 with 5 "Too Easy"
- Reset counter instead of dropping: User at A1 + "Hard" → counter increments but level doesn't change; resets on "Easy"

## Migration Plan

### Phase 1: Backend Schema & Logic (Pre-UI)

1. Create `user_proficiency` table in schema.sql
2. Add `rating` column to `study_events`
3. Implement consecutive counter logic in `/v1/study-events` endpoint
4. Create new `GET /v1/proficiency` endpoint
5. Historical/superseded: enhance `GET /v1/words/next` to accept
   `proficiency_level`; current filtering should be understood through
   `POST /v1/learning/cards`
6. Test: Simulate 5 consecutive ratings; verify level changes
7. Test: Verify word filtering by level

**Deployability**: Feature-flag the proficiency filtering (off by default); proficiency table exists but isn't used until enabled.

### Phase 2: Mobile UI & Default Proficiency

1. Initialize all new devices at A1
2. Add proficiency display widget (top-right corner)
3. Add 4-button rating bar (horizontal, equal widths)
4. Call `GET /v1/proficiency` on app launch to fetch current level
5. On `POST /v1/study-events`, handle proficiency response and update UI
6. Test: E2E flow of rating words and watching level change

**Feature gate**: Roll out to beta users; monitor for gaming, crashes, unexpected behavior.

### Phase 3: Content Migration

1. Audit all words in DB; map `difficulty` to CEFR
2. Ensure LiteLLM generation targets specific CEFR level
3. Run validation: All words should have A1–C2 level
4. Rollout: Enable proficiency filtering in production

**Validation**: Query `SELECT COUNT(*) FROM words WHERE difficulty_level NOT IN ('A1', ..., 'C2')` to catch strays.

### Rollback Strategy

- Phase 1: Disable feature flag; proficiency updates stop but table remains (no data loss)
- Phase 2: Remove proficiency display from UI; users can still rate, just don't see level
- Phase 3: Restore old `difficulty` field as fallback if CEFR mapping fails

## Open Questions

1. **What happens at boundaries?** If user at A1 presses "Hard" 5×, does level drop, or stay at A1? (Recommend: stay at A1; "Hard" rating is still recorded for analytics but doesn't trigger regression below minimum)

2. **Gradient transition duration?** How many words after level-up should show mixed difficulty? (Recommend: 2–3 words; empirically adjust based on telemetry)

3. **Per-user proficiency after auth?** When authentication is added, should proficiency be per-user (shared across devices) or per-device (independent)? (Recommend: per-user with per-device override option for offline learning)

4. **Word shortage at edges?** If user at C2 and no C2 words available, what is fallback? (Recommend: blend down to C1, or show "all words reviewed" message)

5. **Rating interpretation**: What does "Hard" mean exactly? Did user not understand the word, or did they understand but it challenged them? (Define explicitly in UX copy; affects confidence thresholds later)

6. **Offline behavior**: If app is offline and user rates words, how are events and proficiency changes synced? (MVP: assume online-only; future: queue events locally, sync on reconnect)
