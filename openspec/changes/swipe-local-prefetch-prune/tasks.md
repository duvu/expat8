## 1. Prefetch Trigger — Swipe Path

- [x] 1.1 Trong `LearningSessionController.showNewWord()`, gọi `_triggerPrefetchIfNeeded()` sau khi card được load xong (cuối method, trước `notifyListeners()` cuối cùng)
- [x] 1.2 Trong `LearningSessionController.showRecentReview()`, gọi `_triggerPrefetchIfNeeded()` sau khi card được load xong (tương tự 1.1)
- [x] 1.3 Đổi threshold trong `_triggerPrefetchIfNeeded()` từ `count <= 3` thành `count < 100`

## 2. Smart Prune — LocalDatabase

- [x] 2.1 Thêm method `pruneToCapSmartly({int maxWords = 1000})` vào `LocalDatabase`:
  - Pass 1: Lấy danh sách từ có `status == mastered`, sort by `lastSeenAtMs ASC` (null last), xóa từ ít seen nhất trước, skip từ có pending sync
  - Pass 2: Nếu còn > maxWords, lấy danh sách từ `status == review` và `nextReviewAtMs > now + 30 days`, sort by `nextReviewAtMs DESC`, xóa, skip từ có pending sync
  - Pass 3: Fallback — nếu còn > maxWords, sort toàn bộ theo `createdAtMs ASC`, xóa oldest, skip từ có pending sync
- [x] 2.2 Trong `addBatch()`, thay gọi `pruneToMostRecent(maxWords: 1000)` thành `pruneToCapSmartly(maxWords: 1000)`

## 3. Tests

- [x] 3.1 Unit test `pruneToCapSmartly()`: insert 1050 từ với status mix (mastered/review/newWord), verify mastered bị xóa trước, tổng <= 1000
- [x] 3.2 Unit test `pruneToCapSmartly()`: insert 1050 từ không có mastered, review xa > 30 ngày bị xóa trước, tổng <= 1000
- [x] 3.3 Unit test `pruneToCapSmartly()`: từ có pending sync không bị xóa (skip logic hoạt động đúng)
- [x] 3.4 Unit test `_triggerPrefetchIfNeeded()` trong controller: verify prefetch được trigger sau swipe khi count < 100
- [x] 3.5 Chạy `flutter test` để verify không có regression

## 4. Verification

- [ ] 4.1 Manual test: swipe liên tục, confirm backend log nhận `POST /v1/learning/cards` khi local unlearned < 100
- [ ] 4.2 Manual test: load app trên emulator, verify từ xuất hiện ngay khi swipe (không có delay)
