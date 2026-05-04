## Why

The app currently lacks a proficiency system. Users cannot see their level, content cannot be filtered by difficulty, and there's no way to measure learner progress. We need an **adaptive system that automatically detects proficiency level** based on study behavior—specifically, consecutive correct/incorrect ratings—without requiring users to self-assess or manually select a level. This removes friction, provides accurate difficulty matching, and adapts as learners grow.

## What Changes

- Users no longer manually choose or configure their proficiency level; the system auto-detects via study patterns
- Mobile app shows current proficiency level (A1–C2) in top-right corner, always visible
- Mobile app displays 4 rating buttons (`Easy`, `Too Easy`, `Hard`, `Too Hard`) in a single horizontal row with equal widths
- Backend records rating on each study event and triggers automatic proficiency level changes:
  - 5 consecutive "Too Easy" ratings → proficiency level increases by 1 (e.g., A1 → A2)
  - 5 consecutive "Hard" ratings → proficiency level decreases by 1 (e.g., B1 → A2)
  - Any other button press → counter resets
- Backend filters new vocabulary words by the user's current proficiency level to ensure appropriate difficulty
- Default proficiency for new users: A1 (absolute beginner)
- All users start unauthenticated and per-device (proficiency stored per device ID, not user account)

## Capabilities

### New Capabilities

- `adaptive-proficiency-detection`: Automatically detect and advance/regress user proficiency level based on consecutive "Too Easy" (5×) or "Hard" (5×) ratings, without user input
- `proficiency-level-tracking`: Store, retrieve, and update the current proficiency level (A1–C2) per device, integrated with study event history
- `study-event-rating-system`: Record explicit difficulty ratings (`easy`, `too_easy`, `hard`, `too_hard`) on each vocabulary study event to drive proficiency updates
- `proficiency-based-content-filtering`: Filter word feed by the user's current proficiency level to ensure consistent difficulty matching

### Modified Capabilities

- `word-feed-sync`: Existing word-feed API now accepts proficiency level parameter and filters results to match current user level
- `study-events-api`: Existing study-events endpoint now accepts rating field and returns proficiency change details in response

## Impact

**Database Schema**:
- New `user_proficiency` table to store current level per device/language
- New `rating` column in `study_events` table to record difficulty feedback

**Backend APIs**:
- Enhanced `POST /v1/study-events`: Now accepts `rating` field; response includes proficiency change status
- New `GET /v1/proficiency`: Returns current proficiency level for a device
- Enhanced `GET /v1/words/next`: Now accepts `proficiency_level` parameter; filters words to matching difficulty

**Mobile UI**:
- New proficiency display widget in top-right corner of learning screen
- New 4-button rating bar layout in horizontal row with equal button widths
- New level-change notification when proficiency advances/regresses

**Content**:
- All backend vocabulary words must be tagged with CEFR difficulty level (A1–C2)
