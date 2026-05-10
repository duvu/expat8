## 1. LocalDatabase — markWordAsLearning

- [x] 1.1 Thêm method `markWordAsLearning({required VocabularyWord word, required DateTime now})` vào `LocalDatabase`: set `status = learning`, `lastSeenAtMs = now.ms`, `nextReviewAtMs = now + 24h`, rồi `_localWords.put(entity)`

## 2. WordRepository — markWordAsLearning

- [x] 2.1 Thêm method `markWordAsLearning({required VocabularyWord word, required DateTime now})` vào `WordRepository` gọi `database.markWordAsLearning(word: word, now: now)`

## 3. Controller — Advance sau khi show new word

- [x] 3.1 Trong `showNewWord()`, sau khi `_showWord(word, actualKind, ...)`, nếu `word != null && actualKind == CardKind.newWord`, gọi `unawaited(repository.markWordAsLearning(word: word, now: DateTime.now().toUtc()))` (fire-and-forget, không block UI)

## 4. Tests

- [x] 4.1 Unit test `LocalDatabase.markWordAsLearning()`: word chuyển từ `newWord` → `learning`, `nextReviewAtMs` ≈ now + 24h, `lastSeenAtMs` được set
- [x] 4.2 Unit test: sau khi `markWordAsLearning()`, `nextNewWord()` không còn trả về word đó
- [x] 4.3 Unit test controller: swipe right-to-left nhiều lần → mỗi lần hiển thị từ khác nhau (mỗi word được advance sau khi shown)
- [x] 4.4 Chạy `flutter test` — verify không có regression

## 5. Verification

- [x] 5.1 Manual test trên emulator: swipe right-to-left liên tiếp 5 lần, confirm 5 từ khác nhau xuất hiện
