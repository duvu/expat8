## Context

The current learning session renders every card identically: term on front, swipe to reveal meaning, example, and Vietnamese translation. This is passive recognition. FITB sentence cards introduce active recall — the learner must produce the target word from context — without adding new gestures, buttons, or API endpoints.

Key existing constraints:
- Gesture-only UI on the learning screen (no buttons, no skip)
- Backend must not be called at card-serve time; all data comes from the local ObjectBox cache
- `toApiWord()` already returns `term`, `example`, `example_vi`, `entry_type`, and `card_type`
- ~85% of session cards are review cards (`card_type = "review"`); FITB targets this subset only

## Goals / Non-Goals

**Goals:**
- Show FITB version of ~50% of total session cards (~59% of review cards) by randomising at render time
- Blank the key word deterministically: whole `term` for `word` entries; LLM-chosen `blank_word` for `phrase`/`idiom`
- Reveal the blanked word + Vietnamese hint on a single tap anywhere on the card
- Add `blank_word TEXT` column to `words` table, populated by LLM at generation time
- Extend `toApiWord()` with `blank_word`; extend mobile `WordCard` model to carry it
- Guard gracefully: words with null `blank_word` (phrase/idiom) simply render as standard cards

**Non-Goals:**
- Keyboard text-entry input — tap-to-reveal only
- FITB on new cards (`card_type = "new"`)
- Back-filling `blank_word` for existing rows via a script (LLM re-generation is the long-term path)
- Dashboard or backend scoring changes
- Skip/hint buttons

## Decisions

### D1: Blank word source by entry_type
`word` entries blank the entire `term` in the `example` sentence (string replace, case-insensitive).  
`phrase` and `idiom` entries use the `blank_word` DB field; if null, the card renders in standard mode.

**Alternatives considered:**
- Pure heuristic "last content word" for all types: fast to ship, but inaccurate for idioms where the identifying word is rarely last.
- `blank_word` for all three types: unnecessary — single-word terms have an obvious blank target.

### D2: FITB activation threshold — random < 0.59 on review cards
A review card becomes FITB when `Random().nextDouble() < 0.59`. Given 85% of cards are review, this yields ≈50% of total session cards as FITB.

**Alternatives considered:**
- 0.50 threshold → ~42.5% of full session; rejected per user preference.
- Per-word review_count gating (FITB only after N reviews): adds statefulness; deferred to a future progressive-difficulty change.

### D3: Tap-to-reveal; no text entry
The learning screen is gesture-only. Text input would break this paradigm. Tap anywhere on the `FitbCard` reveals the blanked word inline and shows the Vietnamese hint below — matching the same "reveal" mental model as swipe on a standard card.

**Alternatives considered:**
- Swipe-up to reveal: conflicts with the remembered-gesture; rejected.
- Multiple-choice options: introduces buttons; rejected.

### D4: `canFitb()` guard conditions
A card is eligible for FITB only when:
1. `card_type == "review"`
2. `example` is non-empty
3. `example` has ≥ 8 words (ensures context remains meaningful after blanking)
4. `example` contains `term` case-insensitively (confirms blank target is present)
5. `entry_type` is one of `word`, `phrase`, `idiom`
6. For `phrase`/`idiom`: `blank_word` is non-null and non-empty

Failing any guard → standard card rendered.

### D5: DB column is nullable; no backfill required
`blank_word TEXT` added as a nullable column. Old rows have null; `canFitb()` returns false for phrase/idiom with null `blank_word`. This avoids any backfill migration or LLM job. New generations (after prompt update) populate the field automatically.

## Risks / Trade-offs

- **LLM `blank_word` quality**: The LLM may choose an uninteresting blank target (articles, prepositions). Mitigation: prompt instructs to pick the most semantically loaded content word of the phrase; `canFitb()` has no "interesting word" gate — if quality is poor, human curation of `blank_word` is possible via dashboard.
- **Coverage gap on existing content**: Existing phrase/idiom rows have null `blank_word`, so only `word` entries get FITB until re-generation runs. Mitigation: FITB ratio is a UX improvement, not a correctness issue; existing users see a partial rollout naturally.
- **`term` not found in `example`**: Some LLM-generated examples paraphrase rather than use the exact term. The guard catches this (condition 4) and degrades gracefully.
- **Random inconsistency**: The same card may appear as FITB on one swipe and standard on another. This is intentional (random at render time, not at cache time); the variability itself reinforces recall.

## Migration Plan

1. **DB**: Apply `ALTER TABLE words ADD COLUMN blank_word TEXT;` migration (no downtime; additive).
2. **Backend**: Deploy updated `toApiWord()` returning `blank_word` (null for old rows). Old mobile ignores the field; no breaking change.
3. **Worker**: Deploy updated LLM prompt; new vocabulary batches will include `blank_word` for phrase/idiom entries.
4. **Mobile**: Release new build with `FitbCard` widget; `canFitb()` returns false for null `blank_word`, so phrase/idiom cards stay standard until re-generated vocabulary reaches the device cache.

Rollback: remove the `FitbCard` code path (feature-flag it with a compile-time constant if needed); DB column is inert without the mobile code.

## Open Questions

None — all design decisions resolved.
