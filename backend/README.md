# Expat8 Backend Service

Node.js + Express backend for the Expat8 vocabulary app.

## Adaptive Proficiency Overview

The backend tracks proficiency per device and language, and adapts word selection by level.

Core behavior:

- Study ratings accepted: easy, too_easy, hard, too_hard.
- Proficiency is stored in user_proficiency and initialized on demand.
- 5 consecutive too_easy ratings trigger a level-up.
- 5 consecutive hard ratings trigger a level-down.
- Level progression follows language-native scales:
  - English: CEFR (A1 -> C2)
  - Chinese: HSK (HSK1 -> HSK6)
- Word feed can filter by explicit proficiency_level or resolve by device context.

## Key Endpoints

- POST /v1/study-events
- POST /v1/study-events/sync
- GET /v1/proficiency
- GET /v1/words/next
- GET /v1/words/recent

See contracts/api.md for request and response details.

## Running Locally

```bash
cd backend
npm install
npm test
npm start
```
