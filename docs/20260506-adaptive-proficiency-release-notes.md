# Release Notes: Adaptive Proficiency System

Date: 2026-05-06
Change: add-adaptive-proficiency-system

## Highlights

- Added adaptive proficiency progression based on study ratings.
- Added proficiency API endpoint and response enrichment in study-event flows.
- Added proficiency-aware filtering in word feed.
- Added mobile proficiency state integration and UI feedback.

## Backend

- Study events now include rating semantics for progression logic.
- Proficiency state is persisted and returned with compatibility fields where configured.
- Word selection supports proficiency level targeting with fallback strategy.

## Mobile

- Top-right proficiency label on learning screen.
- Four rating buttons: Easy, Too Easy, Hard, Too Hard.
- Level-change message surfaced after progression/regression responses.

## Operational Notes

- Keep compatibility mode additive during migration windows.
- Validate difficulty labels are canonical before ingest.
- Monitor fallback frequency and level transition distribution.
