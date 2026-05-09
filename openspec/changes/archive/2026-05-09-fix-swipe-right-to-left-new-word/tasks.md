## 1. Fix gesture mode

- [x] 1.1 Trong `learning_session_controller.dart`, đổi `onSwipeRightToLeft()` từ `_CardSelectionMode.mixed` sang `_CardSelectionMode.newFirst`

## 2. Tests

- [x] 2.1 Thêm test: right-to-left swipe lần thứ 4 trở đi vẫn hiển thị từ mới (không chuyển sang review sau 3 lần)
- [x] 2.2 Thêm test: right-to-left swipe với empty DB (hết từ mới) → fallback sang non-mastered/random, không crash
- [x] 2.3 Xác nhận test `nextCard()` và `nextCard` post-rating vẫn dùng mixed mode (không thay đổi)
