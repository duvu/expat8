# Adaptive Proficiency Architecture

```mermaid
flowchart TD
  A[Mobile Learning Screen] --> B[POST /v1/study-events]
  A --> C[GET /v1/proficiency]
  A --> D[GET /v1/words/next]

  B --> E[Study Events Store]
  E --> F[Consecutive Counter]
  F --> G[Proficiency Engine]
  G --> H[user_proficiency table]

  D --> I[Word Selection]
  H --> I
  I --> J[Difficulty Filter by scale + level]
  J --> K[Fallback Levels]
  K --> L[Words table]

  C --> H
  B --> M[Proficiency response payload]
  M --> A
```

## Components

- Study event ingestion with rating validation.
- Consecutive rating evaluation for progression/regression.
- Proficiency persistence per device + language.
- Word retrieval with proficiency-aware filtering and fallback.
- Mobile feedback loop for level badge and level-change notifications.
