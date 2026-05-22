# Seed Vocabulary Bundling

**Mục tiêu:** Mobile app phải có sẵn ~1000 từ vựng mỗi ngôn ngữ ngay khi cài đặt, không phải chờ sync. Người dùng mở app → học được ngay.

---

## Kiến trúc

```
┌──────────────────────────────────────────────────────────────────┐
│ App install                                                      │
│   ├─ APK/IPA chứa assets/seed_vocab/{en,zh,vi}.json              │
│   │  (1000 từ mỗi ngôn ngữ, được generate sẵn từ backend)        │
│   │                                                              │
│   └─ App launch lần đầu:                                         │
│        SeedVocabularyLoader đọc bundled JSON                     │
│        → WordRepository.seedFromBundleIfEmpty(languages)         │
│        → addBatch cho từng ngôn ngữ → DB local có ngay 3000 từ   │
│        → User vào màn hình học, có sẵn từ — không chờ network    │
│                                                                  │
│   Background (sau khi runApp):                                   │
│     ├─ syncCacheInventory (báo backend biết những từ đã cache)   │
│     └─ topUpInventoryIfNeeded (rules per spec, no-op khi đủ)     │
└──────────────────────────────────────────────────────────────────┘
```

## Asset layout

`mobile/assets/seed_vocab/<language>.json` — array của vocabulary entries với schema khớp `VocabularyWord.fromJson`:

```json
[
  {
    "server_word_id": "seed_zh_nihao",
    "term": "你好",
    "language": "zh",
    "meaning_vi": "xin chào",
    "part_of_speech": "interjection",
    "ipa": "",
    "vietnamese_pronunciation": "nǐ hǎo",
    "example": "你好,认识你很高兴。",
    "example_vi": "Xin chào, rất vui được gặp bạn.",
    "difficulty": "HSK1",
    "topics": ["greeting"],
    "created_at": "2026-05-08T00:00:00.000Z"
  }
]
```

Các file được declare trong `mobile/pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/seed_vocab/en.json
    - assets/seed_vocab/zh.json
    - assets/seed_vocab/vi.json
```

## Bộ seed hiện tại

| Ngôn ngữ | Số entry | Difficulty range | Note |
|---------|---------:|------------------|------|
| `en` | 50 | A1–A2 | Common everyday words |
| `zh` | 50 | HSK1–HSK2 | Hanzi + pinyin |
| `vi` | 36 | A1–A2 | Cho user non-Vietnamese học tiếng Việt |

Đây là **starter seed**, chưa đến 1000 mỗi ngôn ngữ. Để mở rộng tới mức target, dùng generation script (xem dưới).

## Generation script

`scripts/generate-seed-vocabulary.mjs` lặp gọi backend `/v1/learning/cards` cho đến khi mỗi ngôn ngữ đạt target (default 1000 entries). Script sẽ append entries mới vào file JSON hiện tại — re-run an toàn.

### Cách chạy

```bash
# 1. Khởi động backend (vd. docker compose up -d backend) hoặc trỏ đến staging:
export BACKEND_URL=http://localhost:8787    # hoặc <YOUR_BACKEND_URL>
export APP_ID=expat8-mobile-app             # khớp 1 credential active
export APP_SECRET=<YOUR_APP_SECRET>

# 2. (Optional) tuỳ chỉnh:
export TARGET_PER_LANGUAGE=1000             # default 1000
export LANGUAGES=en,zh,vi                   # default en,zh,vi

# 3. Chạy:
node scripts/generate-seed-vocabulary.mjs
```

Output: cập nhật `mobile/assets/seed_vocab/<language>.json`.

### Backend prerequisites

- Backend phải running và reachable
- Backend cần `LITELLM_API_KEY` để generate khi pool chưa đủ
- Generation tốn tiền LLM — chạy script này có chi phí thực

### Re-running an toàn

Script đọc file hiện tại trước, dùng `server_word_id` làm key dedup. Backend trả về items đã có → bị skip. Chỉ items mới được append. Nếu cần regen từ đầu, xoá file (hoặc replace bằng `[]`) trước khi chạy.

## Behavior thay đổi

### Trước

`main.dart` block startup khi DB rỗng → `await topUpInventoryIfNeeded()` → backend round-trip 200 từ → user chờ. Nếu không có mạng → user thấy "No card available".

### Sau

`main.dart` gọi `seedFromBundleIfEmpty()` sync (đọc file local, < 50ms) → DB có sẵn từ → user vào học ngay. `topUpInventoryIfNeeded()` chạy background, không block UI.

```dart
// mobile/lib/main.dart
await repository.seedFromBundleIfEmpty(
  languages: config.supportedLearningLanguages,
);
unawaited(repository.syncCacheInventory(deviceId: deviceId));
unawaited(repository.topUpInventoryIfNeeded());
```

## Per-language pruning

`LocalDatabase.pruneToCapSmartly` được sửa để chấp nhận `language` parameter (per-language scope). Nếu không thì khi seed 3 ngôn ngữ × 1000 từ = 3000 entries vào DB sẽ vượt cap 1000 toàn cục → 2000 entries bị prune ngẫu nhiên. Sau fix, mỗi ngôn ngữ có cap riêng 1000.

## Tests

| File | Coverage |
|------|----------|
| `mobile/test/seed_vocabulary_loader_test.dart` | Stub bundle reader (missing/malformed/valid JSON) + test loading bundled assets thực |
| `mobile/test/word_repository_test.dart` | `seedFromBundleIfEmpty` skip languages already populated, count đúng theo language |
