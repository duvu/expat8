# API Contracts

## Vocabulary Item

```json
{
  "server_word_id": "word_123",
  "term": "reliable",
  "language": "en",
  "meaning_vi": "dang tin cay",
  "part_of_speech": "adjective",
  "ipa": "/rɪˈlaɪəbl/",
  "vietnamese_pronunciation": "ri-lai-uh-bol",
  "example": "She is a reliable teammate.",
  "example_vi": "Co ay la mot dong doi dang tin cay.",
  "difficulty": "B1",
  "topics": ["work", "people"],
  "created_at": "2026-05-04T00:00:00.000Z"
}
```

## GET /v1/words/next

Query parameters:

- `mode`: `new`
- `limit`: max items to return
- `source_language`: source language code, default `vi`
- `target_language`: target language code, default `en`

Response:

```json
{
  "items": []
}
```

## GET /v1/words/recent

Query parameters:

- `limit`: maximum returned words, capped at `1000`
- `source_language`: source language code
- `target_language`: target language code

Response:

```json
{
  "items": []
}
```

## POST /v1/study-events/sync

Request:

```json
{
  "device_id": "device_abc",
  "events": [
    {
      "client_event_id": "evt_001",
      "server_word_id": "word_123",
      "local_word_id": "local_456",
      "rating": "remembered",
      "occurred_at": "2026-05-04T10:30:00.000Z"
    }
  ]
}
```

Response:

```json
{
  "accepted_event_ids": ["evt_001"],
  "rejected_events": []
}
```
