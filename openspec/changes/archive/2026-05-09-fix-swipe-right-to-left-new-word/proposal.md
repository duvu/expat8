## Why

Swipe phải→trái là gesture duy nhất dùng để học từ mới, nhưng hiện tại nó bị giới hạn bởi `CardSelectionWindow` — sau 3 từ mới trong một window 20 thẻ, gesture này tự chuyển sang hiển thị review card thay vì từ mới. Người dùng mong đợi swipe phải→trái luôn load từ mới từ local database liên tục không dừng.

## What Changes

- `onSwipeRightToLeft()` đổi từ `_CardSelectionMode.mixed` sang `_CardSelectionMode.newFirst` — gesture này luôn ưu tiên từ mới, fallback sang review/random chỉ khi local DB thực sự hết từ mới
- `CardSelectionWindow` và `nextCard()` giữ nguyên `mixed` — tỷ lệ 15%/85% vẫn áp dụng cho điều hướng tự động sau rating
- Xóa `_CardSelectionMode.mixed` khỏi `onSwipeRightToLeft`; `mixed` mode không còn liên quan đến gesture này nữa

## Capabilities

### New Capabilities

*(không có — đây là bug fix semantic mapping)*

### Modified Capabilities

- `mobile-learning-session`: Requirement "Swipe advances the learning session" cần cập nhật — right-to-left swipe SHALL always prefer new-word selection (newFirst), not follow the mixed window target

## Impact

- `mobile/lib/src/session/learning_session_controller.dart` — 1 dòng thay đổi trong `onSwipeRightToLeft()`
- `mobile/test/learning_session_controller_test.dart` — thêm test kiểm tra right-to-left swipe vẫn show từ mới sau 3 lần liên tiếp
- Không thay đổi backend, không thay đổi `CardSelectionWindow`, không thay đổi `nextCard()`
