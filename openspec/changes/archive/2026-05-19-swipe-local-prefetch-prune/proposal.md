## Why

Hiện tại swipe gesture có thể trigger backend call trực tiếp trong một số path, gây ra UX lag và lỗi khi offline. Cần đảm bảo swipe luôn lấy từ local DB (instant), tự động prefetch async khi số từ chưa học xuống dưới 100, và dọn dẹp thông minh (xóa từ đã nhớ kỹ) thay vì xóa theo thứ tự cũ khi local DB vượt quá 1000 từ.

## What Changes

- **Swipe handler** (up/down/left/right) phải luôn lấy từ tiếp theo từ local ObjectBox DB — không gọi backend trực tiếp trong swipe path
- **Auto-prefetch trigger**: sau mỗi swipe, đếm số từ chưa học trong local DB; nếu < 100 → trigger background prefetch 100 từ mới từ backend
- **Smart prune**: sau khi prefetch xong, nếu tổng số từ trong local DB > 1000 → xóa các từ đã được đánh dấu memorized hoặc có repetition count cao (đã học nhiều lần) để duy trì ~1000 từ
- **Prune priority**: ưu tiên xóa theo thứ tự: đã memorized lâu nhất → repetition count cao nhất → oldest first (fallback)

## Capabilities

### New Capabilities
- `swipe-auto-prefetch`: Sau swipe, kiểm tra unlearned word count và trigger background prefetch khi < 100

### Modified Capabilities
- `mobile-learning-session`: Swipe handler bắt buộc lấy từ local DB; không gọi backend trong swipe path
- `mobile-local-cache-sync`: Prune logic ưu tiên xóa từ đã memorized/high-repetition thay vì chỉ xóa oldest

## Impact

- `mobile/lib/src/session/learning_session_controller.dart` — swipe handlers, trigger prefetch check
- `mobile/lib/src/data/word_repository.dart` — `getNextWord()`, `countUnlearnedWords()`, `pruneMemorizedWords()`
- `mobile/lib/src/data/local_database.dart` hoặc ObjectBox entity — query unlearned count, memorized/repetition filter
- Backend không thay đổi (đã hỗ trợ limit=100)
