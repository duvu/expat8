# Investigation: Tiếng Trung E2E Flow

**Ngày:** 2026-05-08
**Trạng thái:** Đã fix ✓

---

## Tóm tắt

Khi người dùng chọn Chinese trong language selector, app hiển thị "No learning card is available". Mobile gửi đúng `target_language: 'zh'`, nhưng backend trả về danh sách rỗng. Trace cho thấy backend không chỉ thiếu Chinese words mà việc generate cũng bị fail vì proficiency / difficulty mapping không tôn trọng language scale.

---

## Luồng e2e Chinese

```
┌────────────────────────────────────────────────────────────────────┐
│ User chọn "Chinese" trong LearningLanguageSelector                 │
│   ↓                                                                │
│ controller.setActiveLearningLanguage('zh')                         │
│   ↓                                                                │
│ ┌─ repository.fetchProficiency(language: 'zh')                     │
│ │     POST /v1/proficiency?language=zh                             │
│ │     → backend.getOrInitializeProficiency(language: 'zh')         │
│ │       ❌ BUG #1: tạo row với level='A1' (CEFR), không phải HSK1   │
│ │     → buildProficiencyResponse()                                 │
│ │       ❌ BUG #3: thiếu scale, level_index trong response         │
│ │                                                                  │
│ ├─ repository.topUpInventoryIfNeeded()                             │
│ │     → countWords(language: 'zh') == 0                            │
│ │     → _safeRefill(limit: 200)  // first install                  │
│ │     → refillLearningCards(limit: 200, language: 'zh')            │
│ │       ❌ BUG #5: clamps to 100                                   │
│ │       → POST /v1/learning/cards {target_language: 'zh', limit: 100}│
│ │         → store.learningCards(targetLanguage: 'zh')              │
│ │           → SELECT * FROM words WHERE language='zh' → 0 rows     │
│ │         → shortfall = 100                                        │
│ │         → generationService.generateAndStore(targetLanguage:'zh')│
│ │           ❌ BUG #4: dùng default difficultyLevel='B1' (CEFR)    │
│ │           → liteLLM prompt: "scale HSK, level B1, must equal B1, │
│ │              must be one of HSK1...HSK6"  ← MÂU THUẪN!           │
│ │           → LLM trả về items với difficulty='B1' hoặc HSK?       │
│ │           → validation: validateDifficultyLevel('B1', zh) → false│
│ │             → tất cả items bị reject với 'invalid_difficulty'    │
│ │         → re-query → vẫn 0 Chinese words                         │
│ │       → API trả về items: []                                     │
│ │     → addBatch([]) → no-op                                       │
│ │                                                                  │
│ └─ controller.showNewWord()                                        │
│       → database.nextNewWord(language: 'zh') → null                │
│       → UI hiển thị "No learning card is available"                │
└────────────────────────────────────────────────────────────────────┘
```

---

## Bugs phát hiện

### Bug #1 (Critical, Backend) — Proficiency init bỏ qua language scale

**Files:**
- `backend/src/postgres_word_store.js:642-688` (`getOrInitializeProficiency`)
- `backend/src/word_store.js:430-448` (`#getOrCreateProficiency`)

**Triệu chứng:**
Khi user chọn Chinese lần đầu, backend INSERT row với `level=DEFAULT_PROFICIENCY_LEVEL='A1'` (CEFR) bất kể `language`. Phải là `HSK1` cho Chinese.

```js
// HIỆN TẠI
INSERT INTO user_proficiency (... level, ...)
VALUES (..., DEFAULT_PROFICIENCY_LEVEL, ...)  // 'A1' luôn
```

**Fix:** Dùng `getDefaultProficiencyLevel({language})`:
```js
const defaultLevel = getDefaultProficiencyLevel({ language }); // 'A1' cho en, 'HSK1' cho zh
```

---

### Bug #2 (Critical, Backend) — `applyProficiencyChange` dùng CEFR scale cho mọi ngôn ngữ

**Files:**
- `backend/src/postgres_word_store.js:#applyProficiencyChange` (line 690+)
- `backend/src/word_store.js:#applyProficiencyChange` (line 389+)

**Triệu chứng:**
Sau 5 `too_easy` rating trên từ Chinese, level transition là A1→A2 (CEFR), phải là HSK1→HSK2.

```js
// HIỆN TẠI
const previousLevel = normalizeDifficultyLevel(currentLevel) ?? DEFAULT_PROFICIENCY_LEVEL;
const nextLevel = rating === 'too_easy'
  ? incrementLevel(previousLevel)        // dùng CEFR profile mặc định
  : decrementLevel(previousLevel);       // dùng CEFR profile mặc định
```

**Fix:** Truyền `{language}` vào tất cả calls:
```js
const previousLevel = normalizeDifficultyLevel(currentLevel, { language })
  ?? getDefaultProficiencyLevel({ language });
const nextLevel = rating === 'too_easy'
  ? incrementLevel(previousLevel, { language })
  : decrementLevel(previousLevel, { language });
```

---

### Bug #3 (Critical, Backend) — Proficiency response thiếu `scale` và `level_index`

**Files:**
- `backend/src/postgres_word_store.js:#buildProficiencyResponse` (line 715+)
- `backend/src/word_store.js:#buildProficiencyResponse` (line 410+)

**Triệu chứng:**
Mobile suy ra scale từ level prefix (`'HSK'` → `hsk`, else `cefr`). Hoạt động cho display, nhưng `level_index` luôn = 0 trong client.

E2E test khẳng định contract: `proficiency.scale === 'hsk'`, `proficiency.level_index === 1` cho HSK2.

**Fix:** Compute và include trong response:
```js
const profile = getProficiencyProfile({ language });
return {
  scale: profile.scale,
  level: proficiency.level,
  level_index: profile.levels.indexOf(proficiency.level),
  ...
};
```

---

### Bug #4 (Critical, Backend) — `generateAndStore` dùng difficulty default 'B1' bất kể language

**File:** `backend/src/generation_service.js:12-17`

**Triệu chứng:** ROOT CAUSE. Khi backend cần generate Chinese words (cache rỗng), `difficultyLevel` mặc định là `'B1'` (CEFR). LiteLLM nhận prompt mâu thuẫn:
> "Target proficiency scale is **HSK** and target level is **B1**. ... difficulty is one of HSK1/HSK2/.../HSK6 and should equal B1"

Kết quả:
- LLM trả về items với `difficulty: 'B1'` → `validateDifficultyLevel('B1', {language: 'zh'})` returns `false` (B1 không thuộc HSK levels) → tất cả bị reject
- Sau 3 attempts, generation fails, backend trả về `items: []`
- Mobile nhận 0 từ Chinese, tiếp tục báo "No learning card is available"

**Callers cần check:**
- `backend/src/app.js:166` — POST /v1/learning/cards (không truyền difficultyLevel)
- `backend/src/vocabulary_pool_scheduler.js:76` — scheduler (không truyền)

**Fix:** Default theo language:
```js
async generateAndStore({
    sourceLanguage = 'vi',
    targetLanguage = 'en',
    limit = 100,
    avoidTerms = [],
    difficultyLevel
  }) {
  const resolvedDifficulty =
    difficultyLevel ?? getDefaultProficiencyLevel({ language: targetLanguage });
  ...
}
```

---

### Bug #5 (Minor, Mobile) — `refillLearningCards` clamp 100 dù first install cần 200

**File:** `mobile/lib/src/data/word_repository.dart:340`

**Triệu chứng:**
```dart
final batch = await apiClient.fetchLearningCards(
  ...
  limit: limit.clamp(1, 100).toInt(),  // luôn ≤ 100
);
```

Khi `topUpInventoryIfNeeded()` ở first-install gọi `_safeRefill(limit: 200)`, chỉ 100 từ thực sự được fetch (backend cũng cap ở 100). User chỉ có 100 từ thay vì 200.

**Fix:** Loop multiple batches khi `limit > 100`:
```dart
final batchCap = 100;
final remaining = limit;
final allItems = <VocabularyWord>[];
while (allItems.length < limit) {
  final batchLimit = min(batchCap, limit - allItems.length);
  final batch = await apiClient.fetchLearningCards(... limit: batchLimit);
  if (batch.items.isEmpty) break;
  allItems.addAll(batch.items);
}
```

---

## Files đã fix

| File | Thay đổi |
|------|----------|
| `backend/src/generation_service.js` | Default `difficultyLevel` từ `'B1'` cứng → `getDefaultProficiencyLevel({language})` |
| `backend/src/postgres_word_store.js` | Init proficiency theo language; level math (increment/decrement/normalize) truyền `{language}`; response thêm `scale` + `level_index` |
| `backend/src/word_store.js` | Cùng các thay đổi cho in-memory store (dùng cho tests) |
| `mobile/lib/src/data/word_repository.dart` | `refillLearningCards` loop multiple 100-batches khi `limit > 100` (first install 200 từ giờ thực sự fetch 200) |
| `backend/test/e2e_smoke.test.js` | Test Chinese HSK update để gọi endpoint `/v1/learning/cards` thực có thay vì `/v1/words/next` không tồn tại |

## Kết quả test

- **Backend**: 86/89 tests pass (1 pre-existing schema test thất bại, không liên quan; 2 tests skipped là e2e prod cần `RUN_PROD_E2E=1`)
- **Mobile**: 89/89 tests pass
- **`dart analyze --fatal-infos`**: clean

E2E Chinese-specific tests:
- `e2e: chinese HSK progression reaches HSK2 and drives level-aware selection` — ✓ PASS (HSK1 → HSK2, scale='hsk', level_index=1)
- `e2e: proficiency stays isolated by language for the same device` — ✓ PASS
