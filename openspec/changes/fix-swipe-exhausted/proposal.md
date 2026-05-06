## Why

Mỗi lần swipe right-to-left, `nextNewWord()` luôn trả về cùng một từ (từ mới nhất theo `createdAtMs DESC`) vì status của từ không thay đổi khi chỉ hiển thị, dẫn đến người dùng thấy cùng một từ mãi mãi thay vì lần lượt các từ mới khác nhau. Cần fix ngay để trải nghiệm học từ không bị stuck.

## What Changes

- Khi `showNewWord()` hiển thị thành công một từ có status `newWord`, tự động chuyển từ đó sang `learning` (coi như "đã xem lần đầu").
- Thêm method `markWordAsLearning()` vào `WordRepository` và `LocalDatabase` để transition `newWord` → `learning` với `nextReviewAtMs = now + 24h`.
- Sau khi fix, mỗi swipe right-to-left sẽ hiển thị từ mới khác nhau vì `nextNewWord()` loại bỏ từ đã chuyển sang `learning`.

## Capabilities

### New Capabilities
- `new-word-advance`: Khi từ `newWord` được hiển thị lần đầu, chuyển sang `learning` để pool words tiến lên và không bị stuck.

### Modified Capabilities
- `mobile-learning-session`: Flow `showNewWord()` giờ có thêm bước advance word status sau khi hiển thị.

## Impact

- `mobile/lib/src/session/learning_session_controller.dart` — thêm lời gọi advance sau `_showWord()`
- `mobile/lib/src/data/word_repository.dart` — thêm `markWordAsLearning()`
- `mobile/lib/src/data/local_database.dart` — thêm `markWordAsLearning()`
- Không breaking API với backend
- Không thay đổi SRS schedule logic hiện có
