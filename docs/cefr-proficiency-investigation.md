# Investigation: CEFR Proficiency Hierarchy (A1 -> C2)

> Historical note (2026-05-06): this investigation predates later API
> consolidation. Mentions of enhancing `/v1/words/next` are historical; current
> card loading uses `POST /v1/learning/cards`.

Date: 2026-05-04

## Problem Statement

The app currently treats `difficulty` as a loose label, but we need a real proficiency hierarchy for language content, for example English levels from A1 to C2 using the European CEFR scale.

The key question is not only "what label do we store?", but also:

- How do we represent ordered levels cleanly?
- How do we keep the mobile learning flow simple?
- How do we avoid depending on the AI model to self-assign levels correctly?
- How do we preserve existing content that already uses labels like `beginner`, `intermediate`, `advanced`, or `B1`?

## What the Codebase Already Shows

### Current state

- `difficulty` is already present on the server and mobile models.
- The field is currently a free-form string, not a structured enum or nested model.
- Seed data and generated content already use mixed values such as `B1`, `beginner`, and `intermediate`.

### Evidence

- Backend validation only checks that `difficulty` exists, not that it is a valid CEFR value: [backend/src/vocabulary_validator.js](/home/beou/IdeaProjects/expat8/backend/src/vocabulary_validator.js)
- Server word storage persists `difficulty` as-is without normalization: [backend/src/word_store.js](/home/beou/IdeaProjects/expat8/backend/src/word_store.js)
- Docs already mention CEFR-like labels, but only as examples, not as a strict system: [docs/language-learning-app.md](/home/beou/IdeaProjects/expat8/docs/language-learning-app.md)
- The repo contains a mix of difficulty values in query output and tests, including `beginner`, `intermediate`, `advanced`, and `B1`: [docs/backend-real-query-output.md](/home/beou/IdeaProjects/expat8/docs/backend-real-query-output.md)

### Practical implication

The current system can store a word, but it cannot reliably answer questions like:

- What is the user's current CEFR level?
- What levels should this session draw from?
- Can we show a beginner user only A1-A2 content?
- Can we progressively unlock B1-B2 and later C1-C2?

## Recommended Model

Use CEFR as the canonical proficiency axis, and treat it as an ordered progression rather than an arbitrary string.

```text
A1 -> A2 -> B1 -> B2 -> C1 -> C2
```

### Suggested shape

Keep two separate concepts:

1. `difficulty_level`: the canonical CEFR value, one of `A1`, `A2`, `B1`, `B2`, `C1`, `C2`.
2. `difficulty_band` or `skill_stage` if the product needs broader groupings such as `beginner`, `intermediate`, `advanced`.

This avoids losing information:

- CEFR is precise enough for curriculum and generation.
- Broader bands are useful for UX, onboarding, and simple filters.

### Why this is better than one free-form `difficulty` string

- It gives an ordered scale that can drive content selection.
- It makes AI generation prompts easier to constrain.
- It makes filtering and analytics predictable.
- It allows old values to be mapped instead of deleted.

## Solution Options

### Option 1: Keep one string field and standardize values

Store only a single normalized string, for example `A1` or `B1`.

Pros:

- Minimal schema change.
- Easy to retrofit.

Cons:

- Still weakly typed.
- Hard to support broader bands and progression rules cleanly.
- Old values like `beginner` need repeated mapping logic.

### Option 2: Canonical CEFR level + optional coarse band

Store one canonical CEFR level and derive a broader band when needed.

Example mapping:

- `A1`, `A2` -> `beginner`
- `B1`, `B2` -> `intermediate`
- `C1`, `C2` -> `advanced`

Pros:

- Best balance of precision and product simplicity.
- Easy to use in prompts, queries, analytics, and UI.
- Existing labels can be mapped without losing the canonical level.

Cons:

- Slightly more work than a single string field.

### Option 3: Hierarchical curriculum tree

Model levels as a tree with subskills, such as grammar, vocabulary, reading, listening, speaking, and writing.

Example:

```text
CEFR
├── A1
├── A2
├── B1
│   ├── vocab
│   ├── reading
│   └── speaking
└── ...
```

Pros:

- Strongest long-term curriculum model.
- Can power personalized lesson paths.

Cons:

- Too much for MVP if the app only needs word-level progression.
- Requires more content design and metadata.

## My Recommendation

For this app, the best next step is:

1. Make CEFR level the canonical proficiency field.
2. Keep a coarse band for UI and quick filtering.
3. Map old `difficulty` values into the new canonical levels.
4. Let AI generate or suggest the level, but do not trust AI alone; validate against allowed CEFR values.

```text
input content / curriculum
        |
        v
canonical CEFR level (A1..C2)
        |
        +--> coarse band for UI (beginner/intermediate/advanced)
        |
        +--> filters for session selection
        |
        +--> analytics / progression
```

## Migration Strategy

### Phase 1: Normalize without breaking existing data

- Keep the current `difficulty` field.
- Introduce a canonical CEFR mapping layer in code.
- Map existing values:
  - `beginner` -> `A1` or `A2` depending on content policy
  - `intermediate` -> `B1` or `B2`
  - `advanced` -> `C1` or `C2`
  - Existing exact CEFR strings remain unchanged

### Phase 2: Add strict validation

- Allow only `A1`, `A2`, `B1`, `B2`, `C1`, `C2` as canonical values.
- Reject or normalize anything else at ingestion time.

### Phase 3: Use level in generation and selection

- Prompt LiteLLM with the target CEFR level.
- Filter stored words by level for session selection.
- Let the session choose a target range based on learner progress.

## Risks and Open Questions

### Risks

- AI-generated content may still drift from the requested level.
- Existing mixed difficulty labels may cause inconsistent analytics if not normalized.
- If we keep both `difficulty` and `level`, we need a single source of truth to avoid drift.

### Open questions

- Do we want the level to be user-configurable at onboarding?
- Should the app start at A1 by default and unlock upward automatically?
- Do we need separate levels per language, or only for English in MVP?
- Should the mobile session use level as a hard filter or a soft preference?

## Suggested MVP Decision

For MVP, I would keep the product simple:

- Canonical `difficulty_level`: `A1` through `C2`
- Optional coarse UI band: beginner / intermediate / advanced
- Default learner starting point: `A1`
- Session selection: prefer the learner's current level and the adjacent level above it
- AI generation: request a specific CEFR target level, then validate the result before saving

This gives us a real proficiency ladder without over-engineering the first version.

---

# Adaptive Proficiency Progression System

Date: 2026-05-04

## Vision Statement

The app does not ask users to pick a level. Instead, it **automatically detects and adjusts the user's proficiency** based on their study behavior. The system uses spaced repetition patterns—consecutive "Too Easy" and "Hard" ratings—to determine when to unlock a higher level or drop back to an easier level.

**User does not manually choose a level.** System auto-detects via study patterns.

## Core Rules

### Rule 1: Level Progression (Unlock Higher Level)

**Trigger**: User presses "Too Easy" 5 times in a row.

**Effect**: Proficiency level increases by 1 (e.g., A1 → A2).

**Subsequent word requests**: Backend filters new words to the new level.

### Rule 2: Level Regression (Drop Back to Easier Level)

**Trigger**: User presses "Hard" 5 times in a row.

**Effect**: Proficiency level decreases by 1 (e.g., B1 → A2).

**Subsequent word requests**: Backend filters new words to the lower level.

### Rule 3: Counter Reset

**Trigger**: User presses any button other than the consecutive one (e.g., after 3 "Too Easy", they press "Easy").

**Effect**: The consecutive counter resets to 0.

**Rationale**: We want *consecutive* same-type ratings, not cumulative ones.

---

## Mobile UI Design

### Layout: Proficiency Display + Rating Buttons

```
┌─────────────────────────────────────────────────┐
│  ← Back                          Proficiency: B1│
├─────────────────────────────────────────────────┤
│                                                 │
│              [Vocabulary Card]                  │
│                    term: "persevere"             │
│                                                 │
│              [Example Sentence]                 │
│              "She perseveres through ..."       │
│                                                 │
│                                                 │
├─────────────────────────────────────────────────┤
│  ┌──────────┬──────────┬──────────┬──────────┐  │
│  │  Easy    │ Too Easy │   Hard   │Too Hard  │  │
│  └──────────┴──────────┴──────────┴──────────┘  │
└─────────────────────────────────────────────────┘
```

### Top-Right Corner: Proficiency Display

- **Position**: Top-right corner, always visible
- **Format**: Text label showing current CEFR level (e.g., "A1", "B1", "C2")
- **Styling**: Small font, subtle background or no background, non-intrusive
- **Updates**: Real-time when level changes (after 5th consecutive rating)

### Rating Buttons: Horizontal 4-Button Bar

- **Button Order** (left to right): `Easy` → `Too Easy` → `Hard` → `Too Hard`
- **Layout**: 4 buttons in 1 horizontal row
- **Width**: Each button has **equal width** (25% of available space)
- **Height**: Comfortable touch target, e.g., 56dp (Material Design standard)
- **Visual Feedback**: 
  - Pressed state shows feedback (highlight or ripple)
  - No button text overflow (short labels)
- **Semantics**:
  - `Easy`: Word was easy, but learner could handle it
  - `Too Easy`: Word was too easy, learner is ready for harder content → **triggers level up**
  - `Hard`: Word was difficult for the learner → **triggers level down**
  - `Too Hard`: Word was impossible, learner was overwhelmed (does not trigger level change, but may affect other metrics)

---

## Example User Journey

### Scenario: User starts at A1

```
Word 1: "dog"
  → User presses: Easy (counter = 0 for "Too Easy", counter = 1 for "Easy")
  
Word 2: "cat"
  → User presses: Easy (counter = 1 for "Easy", counter = 2)
  
Word 3: "run"
  → User presses: Too Easy (counter resets; now counter = 1 for "Too Easy")
  
Word 4: "jump"
  → User presses: Too Easy (counter = 2 for "Too Easy")
  
Word 5: "walk"
  → User presses: Too Easy (counter = 3)
  
Word 6: "skip"
  → User presses: Too Easy (counter = 4)
  
Word 7: "hop"
  → User presses: Too Easy (counter = 5)
  
  ✅ LEVEL UP TRIGGERED!
  Proficiency: A1 → A2
  Top-right corner now shows "A2"
  
Word 8 (next session): Backend filters for A2 words only
```

---

## Backend Schema Changes

### New Field: User Proficiency Level

Where to store it:

**Option A: Separate `user_proficiency` table**

```sql
CREATE TABLE user_proficiency (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE, -- or device_id for now
  language VARCHAR(10) NOT NULL,
  level VARCHAR(2) NOT NULL, -- A1, A2, B1, B2, C1, C2
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE (user_id, language)
);
```

**Option B: Add field to existing `study_events` or `user_word_states` table**

Less clean; creates redundancy if multiple records per user exist.

**Recommendation**: Use **Option A** (separate table) for clarity and query efficiency.

### Enhanced `study_events` Table

Add fields to track consecutive ratings:

```sql
ALTER TABLE study_events ADD COLUMN (
  rating VARCHAR(20), -- "easy", "too_easy", "hard", "too_hard"
  device_id UUID, -- or user_id once auth is added
  last_same_rating_count INT DEFAULT 0 -- e.g., 3 consecutive "too_easy"
);
```

### Tracking Consecutive Ratings

**Backend responsibility**:

1. On each study event submission, record the `rating`.
2. Query the last 10 study events for the same `device_id`.
3. Count consecutive ratings from most recent backward.
4. If count reaches 5 and it's "too_easy" → increment `user_proficiency.level`.
5. If count reaches 5 and it's "hard" → decrement `user_proficiency.level`.
6. Update `user_proficiency.updated_at`.

**Pseudo-code**:

```javascript
async function submitStudyEvent(eventData) {
  const { deviceId, wordId, rating } = eventData;
  
  // 1. Insert study event
  const newEvent = await db.study_events.insert({
    device_id: deviceId,
    word_id: wordId,
    rating: rating,
    timestamp: now()
  });
  
  // 2. Count consecutive same rating
  const recentEvents = await db.study_events
    .where({ device_id: deviceId })
    .orderBy('timestamp', 'DESC')
    .limit(10);
  
  let consecutiveCount = 0;
  for (const event of recentEvents) {
    if (event.rating === rating) {
      consecutiveCount++;
    } else {
      break; // Stop at first different rating
    }
  }
  
  // 3. Trigger level change if threshold met
  if (consecutiveCount === 5) {
    if (rating === 'too_easy') {
      await incrementProficiency(deviceId);
    } else if (rating === 'hard') {
      await decrementProficiency(deviceId);
    }
  }
  
  return newEvent;
}
```

---

## API Changes

### 1. POST `/v1/study-events` (Enhanced)

**Request**:

```json
{
  "device_id": "device-uuid-or-anon-id",
  "word_id": "word-server-id",
  "rating": "too_easy"  // "easy" | "too_easy" | "hard" | "too_hard"
}
```

**Response**:

```json
{
  "success": true,
  "event_id": "event-uuid",
  "proficiency": {
    "level": "A2",
    "level_changed": true,
    "previous_level": "A1",
    "triggered_by": "5x consecutive too_easy"
  }
}
```

### 2. GET `/v1/proficiency` (New)

**Request**:

```
GET /v1/proficiency?device_id=device-uuid
```

**Response**:

```json
{
  "device_id": "device-uuid",
  "level": "B1",
  "language": "en",
  "last_updated": "2026-05-04T10:30:00Z",
  "consecutive_current_rating": 3,
  "current_rating_type": "easy"
}
```

**Purpose**: Mobile app fetches current proficiency on app start.

### 3. GET `/v1/words/next` (Enhanced)

**Existing behavior**: Filters by target language and excluded word IDs.

**New behavior**: Also filters by proficiency level.

```
GET /v1/words/next?target_language=en&proficiency_level=B1&limit=1
```

**Backend**:

```sql
SELECT * FROM words
WHERE language = $1
  AND difficulty_level = $2  -- Match user's current proficiency
  AND id NOT IN ($3, $4, ...) -- Exclude already-seen words
ORDER BY created_at DESC
LIMIT 1;
```

---

## Mobile UI Implementation Notes

### Flutter/Dart

**Proficiency Display (Top-Right)**:

```dart
// In learning_screen.dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Learning'),
      actions: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Level: ${controller.proficiency.level}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        // Vocabulary Card Widget
        _buildVocabularyCard(),
        // Rating Buttons
        _buildRatingButtonBar(),
      ],
    ),
  );
}

Widget _buildRatingButtonBar() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        flex: 1,
        child: _ratingButton('Easy', onPressed: () => submitRating('easy')),
      ),
      Expanded(
        flex: 1,
        child: _ratingButton('Too Easy', onPressed: () => submitRating('too_easy')),
      ),
      Expanded(
        flex: 1,
        child: _ratingButton('Hard', onPressed: () => submitRating('hard')),
      ),
      Expanded(
        flex: 1,
        child: _ratingButton('Too Hard', onPressed: () => submitRating('too_hard')),
      ),
    ],
  );
}

Widget _ratingButton(String label, {required Function() onPressed}) {
  return Padding(
    padding: EdgeInsets.symmetric(horizontal: 4),
    child: ElevatedButton(
      onPressed: onPressed,
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
}
```

**Proficiency Display Update on Level Change**:

```dart
// In learning_session_controller.dart
async void submitRating(String rating) {
  final response = await api.submitStudyEvent({
    'device_id': deviceId,
    'word_id': currentWord.serverId,
    'rating': rating,
  });
  
  if (response['proficiency']['level_changed'] == true) {
    // Animate level change notification
    showLevelUpNotification(
      previousLevel: response['proficiency']['previous_level'],
      newLevel: response['proficiency']['level'],
    );
    
    // Update proficiency state
    proficiency.level = response['proficiency']['level'];
    notifyListeners();
  }
  
  // Load next word with new proficiency level
  await loadNextWord();
}
```

---

## Design Decisions & Rationale

### Why auto-detect instead of user choice?

1. **Reduces friction**: No onboarding form asking "What's your English level?"
2. **More accurate**: User behavior is more honest than self-assessment.
3. **Adaptive**: System naturally responds to learner growth.
4. **Less intimidating**: New learners don't have to label themselves.

### Why 5 consecutive ratings?

1. **Threshold avoids noise**: Single bad day doesn't drop level.
2. **Spaced repetition principle**: Multiple data points = more confidence.
3. **Reasonable session length**: ~5-10 words per session feels natural for mobile.
4. **Easy to implement**: Simple counter, no ML required.

### Why separate proficiency table?

1. **Normalization**: One proficiency record per user/language.
2. **Query efficiency**: Fast lookup without scanning all study events.
3. **Clear schema**: Separates state (proficiency) from events (study_events).
4. **Future expansion**: Can add fields like `streak`, `confidence_score` without polluting events.

### Why top-right corner for proficiency?

1. **Non-intrusive**: Doesn't block card or buttons.
2. **Always visible**: User can see their level without extra navigation.
3. **Conventional**: Top-right is standard for status info in mobile apps.
4. **Feedback**: Level change is immediately visible.

---

## Open Questions

1. **Device vs. User**: Currently using `device_id` (anonymous). When authentication is added, should proficiency be per-user across devices, or per-device per user?

2. **Boundaries**: What happens at the edges?
   - User at A1, presses "Hard" 5 times → Does proficiency stay A1, or do we add a "Pre-A1" level?
   - User at C2, presses "Too Easy" 5 times → Stay at C2 or add a "C2+" or mastery indicator?

3. **Level-Up Momentum**: After user levels up, do they immediately get C2+ words, or do they get a few B1 words before filtering?
   - **Option A** (aggressive): Immediately filter to new level.
   - **Option B** (gradual): Mix 70% new level + 30% old level for 3 words, then full new level.

4. **"Too Hard" Button**: Why have it if it doesn't trigger level change? Possible uses:
   - Log extreme difficulty for analytics?
   - Show "hint" or "skip" affordance?
   - Track learner confidence separately from proficiency?

5. **Sync & Persistence**: When user switches devices, how is proficiency shared?
   - For MVP: Store per-device, no sync (simple).
   - Future: User account + sync across devices.

6. **Word Difficulty Labels**: Do we require all backend words to have a CEFR level? What about legacy words with `beginner` or `B1`?
   - **Option A**: Migrate all words to canonical CEFR (one-time data cleanup).
   - **Option B**: Map free-form labels on-the-fly in backend (more flexible, but slower).

---

## Risks & Mitigations

### Risk 1: User "games" the system by repeatedly pressing "Too Easy"

**Mitigation**:
- Add telemetry to detect unnatural patterns (5 "Too Easy" in < 1 minute).
- Add a cooldown: Proficiency can only change once per session.
- Show visual feedback when approaching threshold (e.g., "4 / 5 too easy").

### Risk 2: Counter logic bugs (e.g., out-of-order submissions, network retries)

**Mitigation**:
- Always re-compute consecutive count from database on each submission (don't trust client state).
- Use database transaction to ensure atomic read + update.
- Log all level changes with timestamp and event trail.

### Risk 3: Rapid level changes (5 "Too Easy" → level up → next word still too easy → 5 more "Too Easy")

**Mitigation**:
- Add a small buffer: After level change, show 1-2 words from adjacent lower level before full filter.
- Or: Increase threshold slightly (e.g., 7 consecutive instead of 5) to allow more evidence.

### Risk 4: "Hard" ratings don't have a clear recovery path

**Mitigation**:
- Once proficiency drops, make it easy to climb back (e.g., "Easy" counts toward next level-up, or lower threshold).
- Or: Use absolute rating counts, not consecutive (e.g., 5 "Too Easy" in last 10 words).

---

## Suggested Phasing

### Phase 1: Core System (MVP)

- ✅ Schema: Add `user_proficiency` table, enhance `study_events` with `rating`.
- ✅ Backend: Implement consecutive rating counter and level change logic.
- ✅ API: Expose `POST /v1/study-events` with rating, `GET /v1/proficiency`, enhance `/v1/words/next`.
- ✅ Mobile: Add rating buttons (4 horizontal), proficiency display (top-right), handle level-up notification.
- ✅ Default: All users start at A1; system auto-detects upward/downward from behavior.

### Phase 2: Analytics & UI Polish

- Add telemetry: Track time-to-level-up, drop rates, rating distribution.
- Add visual feedback: Progress bar toward next level (e.g., "3/5 too easy").
- Add streak indicator: Show "3 easy in a row" or similar.

### Phase 3: Learning Path & Content Curation

- Curriculum design: Ensure word difficulty labels match CEFR precisely.
- Content filtering: Recommend words by level and topic.
- Spaced repetition: Revisit older words at longer intervals.

---

## Implementation Checklist

- [ ] Create `user_proficiency` table in schema.sql
- [ ] Add `rating` column to `study_events`
- [ ] Implement consecutive counter logic in backend
- [ ] Add level-change trigger logic
- [ ] Create `/v1/proficiency` GET endpoint
- [ ] Enhance `/v1/study-events` POST endpoint with rating + proficiency response
- [ ] Enhance `/v1/words/next` to filter by proficiency level
- [ ] Build proficiency display widget in Flutter
- [ ] Build 4-button rating bar in Flutter with equal widths
- [ ] Handle level-up notification in mobile app
- [ ] Test: Simulate 5 consecutive "too_easy" and verify level change
- [ ] Test: Simulate mixed ratings and verify counter reset
- [ ] Test: Verify backend proficiency query efficiency
- [ ] Document API in contracts/api.md
- [ ] Update backend README with proficiency system overview
