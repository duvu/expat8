## 1. Shared learning state

- [x] 1.1 Add local persistence for ordered learned-item history and per-item learned/remembered/difficult state.
- [x] 1.2 Add aggregation helpers that compute learned, remembered, and difficult totals from local state.
- [x] 1.3 Ensure existing vocabulary and workplace sentence records can backfill the new state fields safely.

## 2. Gesture flow updates

- [x] 2.1 Update the shared gesture mapping so right-to-left learns-and-advances, left-to-right opens history, bottom-to-top marks remembered, and top-to-bottom marks difficult.
- [x] 2.2 Apply the shared gesture behavior to the vocabulary learning screen.
- [x] 2.3 Apply the shared gesture behavior to the workplace sentence learning screen.
- [x] 2.4 Make gesture handling persist local state before any sync or refill work.

## 3. History and stats UI

- [x] 3.1 Build the ordered history view that replays items in the exact order they were learned.
- [x] 3.2 Build the learning progress stats page with learned, remembered, and difficult totals.
- [x] 3.3 Wire navigation from both learning screens to the history view and stats page.

## 4. Verification

- [x] 4.1 Add or update widget/controller tests for all four swipe directions on vocabulary and sentence screens.
- [x] 4.2 Add tests for the ordered history view and stats page counts.
- [x] 4.3 Run the relevant Flutter test subset and fix any regressions.
