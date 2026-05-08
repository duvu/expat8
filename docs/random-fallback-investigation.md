# Investigation: "Rất ít từ vựng sẵn sàng" khi mở app

**Ngày:** 2026-05-08
**Trạng thái:** Đã fix ✓

---

## Vấn đề

User mở app → thấy rất ít từ vựng để học (cùng một từ lặp lại). User muốn:
1. Hệ thống sẵn sàng ngay khi mở app
2. Khi hết từ "mới" → random các từ chưa được mark là đã nhớ (status ≠ mastered)

---

## Phân tích nguyên nhân

Trace qua fallback chain hiện tại của `WordRepository.getNewWordWithFallbackResult()`:

```
1. database.nextNewWord(language)             ← chỉ status='newWord'
2. nextDifficultRelearnWord(now, language)    ← chỉ status='learning' AND due
3. recentlyLearnedReviewWord(language)        ← lastSeenAtMs != null, sort by lastSeen DESC
4. nextDueReviewWord(now, language)           ← due review only
```

### Kịch bản fail dẫn đến "rất ít từ"

**Tình huống**: User đã học hết từ trong batch 200 từ đầu tiên.

```
user studies word → markWordAsLearning(word) → status='learning', nextReviewAt = now + 24h
```

Sau khi học hết:
- 200 từ → tất cả status='learning'
- `nextReviewAtMs = now + 24h` cho mọi từ vừa học
- **Step 1 fail**: `nextNewWord` → null (không còn newWord)
- **Step 2 fail**: `nextDifficultRelearnWord` → null (chưa từ nào due, đều +24h)
- **Step 3 problem**: `recentlyLearnedReviewWord` → trả về từ user **vừa swipe** (sort by lastSeen DESC, nên luôn là từ mới nhất)
- User thấy lặp lại cùng vài từ vừa học → cảm giác "rất ít từ"

### Vấn đề phụ: fallback chain còn chứa từ mastered

`recentlyLearnedReviewWord` filter `status.oneOf([learning, review, mastered])` — bao gồm cả mastered. Khi user đã swipe-up mark "đã nhớ" một số từ, những từ đó vẫn xuất hiện trong fallback. User không muốn thấy lại từ đã ghi nhớ.

---

## Giải pháp

Thay toàn bộ fallback chain phức tạp bằng quy tắc đơn giản theo spec:

```
1. database.nextNewWord(language)             ← từ chưa học
2. database.randomNotMasteredWord(language)   ← random từ status ≠ mastered (đa dạng)
3. else: "No learning card available"
```

### Implementation

**Database layer (`LocalDatabase`)**
- Thêm `randomNotMasteredWord(language)`: query tất cả từ với `status != mastered` và pick random (`dart:math.Random`)

**Repository layer (`WordRepository.getNewWordWithFallbackResult`)**
- Thay `getReviewFallbackResult` chain bằng `randomNotMasteredWord`
- Trả về source mới `WordLookupSource.randomFallback`
- Log event `new_word.random.fallback` để theo dõi tần suất

**Lookup source enum**
- Thêm `WordLookupSource.randomFallback`
- Controller `_trackNewWordLookup` track như `newWordLocalFallback`

---

## Files đã fix

| File | Thay đổi |
|------|----------|
| `mobile/lib/src/data/local_database.dart` | Thêm `randomNotMasteredWord(language)`; import `dart:math` |
| `mobile/lib/src/data/word_repository.dart` | Replace fallback chain trong `getNewWordWithFallbackResult` bằng `randomNotMasteredWord`; thêm `WordLookupSource.randomFallback` |
| `mobile/lib/src/session/learning_session_controller.dart` | Handle `WordLookupSource.randomFallback` trong `_trackNewWordLookup`, `_trackReviewLookup`, `_kindForSource`, `_sourceName` |
| `mobile/test/word_repository_test.dart` | Update test "falls back to recently learned" → "falls back to a random non-mastered word"; thêm test "random fallback skips mastered words" |

## Behavior mới

```
showNewWord()
  ↓
getNewWordWithFallbackResult(language)
  ↓
  ┌─ database.nextNewWord(language)        ← từ chưa từng học
  │   nếu có → trả về, source=localFallback, log 'new_word.local.hit'
  │
  ├─ database.randomNotMasteredWord(language) ← random từ status ≠ mastered
  │   nếu có → trả về, source=randomFallback, log 'new_word.random.fallback'
  │
  └─ trả về null, source=none, log 'new_word.local.empty'
```

Mastered = từ user đã swipe-up đánh dấu "đã nhớ" hoặc rate `tooEasy`. Random fallback **không** chọn các từ này — đảm bảo user chỉ thấy từ vẫn cần học.

## Kết quả test

- **Mobile**: 90/90 tests pass
- **`dart analyze`**: clean
- 2 tests mới cho random fallback: ✓ pass
