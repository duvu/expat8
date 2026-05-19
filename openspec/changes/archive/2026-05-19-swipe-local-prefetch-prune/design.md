## Context

Hiện tại swipe đã lấy từ local DB qua `getNewWordWithFallbackResult()` / `getRecentReviewWordResult()` — không có backend call trực tiếp trong swipe path. Tuy nhiên:

1. **Prefetch threshold quá thấp**: `_triggerPrefetchIfNeeded()` chỉ trigger khi `count <= 3` (từ unstudied). Với batch 100, ngưỡng hợp lý là < 100.
2. **Prefetch chỉ trigger sau rating**: Gọi từ `submitRating()` nhưng không gọi từ `showNewWord()` / `showRecentReview()`. Nếu user swipe mà không rate, prefetch không được trigger.
3. **Prune logic không thông minh**: `pruneToMostRecent()` xóa các từ ít được seen nhất, không ưu tiên từ đã mastered hoặc review xa — những từ "không còn cần học".

**Trạng thái hiện tại quan trọng:**
- `LocalWordEntity.status`: `newWord | learning | review | mastered`
- `pruneToMostRecent()` sort theo `lastSeenAt DESC`, giữ top N, xóa rest
- `countUnstudiedNewWords()` count các từ có `status == newWord`
- `prefetchBatch(batchSize: 100)` đã hoạt động và backend hỗ trợ limit=100
- `addBatch()` gọi `pruneToMostRecent(maxWords: 1000)` sau khi insert

## Goals / Non-Goals

**Goals:**
- Mỗi swipe (new word hoặc review) trigger kiểm tra unlearned count và prefetch async nếu cần
- Prefetch trigger khi unlearned < 100 (thay vì <= 3)
- Sau khi prefetch xong, prune ưu tiên từ `mastered` và `review` xa (đã học kỹ) thay vì chỉ oldest
- Local DB luôn ≤ 1000 từ

**Non-Goals:**
- Thay đổi backend API
- Thêm repetition count field vào ObjectBox entity (tránh code regeneration)
- Cross-device sync prune decisions
- Thay đổi swipe gesture mapping (left/right/up/down đã đúng)

## Decisions

### D1: Trigger prefetch check sau mỗi swipe, không chỉ sau rating
**Quyết định**: Gọi `_triggerPrefetchIfNeeded()` ở cuối `showNewWord()` và `showRecentReview()` trong `LearningSessionController`, thêm vào chỗ đã có trong `submitRating()`.
**Lý do**: Không phải lúc nào user cũng rate card. Nếu user chỉ swipe qua mà không rate, prefetch sẽ không được trigger. Swipe là action chính của user.

### D2: Threshold prefetch = 100 unlearned words
**Quyết định**: Đổi điều kiện từ `count <= 3` thành `count < 100`.
**Lý do**: Backend đã hỗ trợ batch 100. Giữ buffer 100 từ đảm bảo user không bao giờ thấy màn hình "no card" khi offline ngắn. Ngưỡng 3 quá thấp — chỉ có 3 từ buffer.
**Alternative**: Dùng config value `vocabProactiveMinNew` đã có (hiện là 10). Rejected — config này là cho luồng khác, dễ gây nhầm lẫn.

### D3: Smart prune — ưu tiên từ mastered và review xa
**Quyết định**: Thêm method `pruneToCapSmartly({int maxWords = 1000})` trong `LocalDatabase`:
- Bước 1: Collect từ có `status == mastered` → sort by `lastSeenAt ASC` (ít seen nhất trước) → đây là ứng viên xóa đầu tiên
- Bước 2: Nếu còn cần xóa, collect từ `status == review` và `nextReviewAt > now + 30 days` → sort by `nextReviewAt DESC` (xa nhất trước)
- Bước 3: Fallback — xóa từ cũ nhất theo `createdAt ASC`
- Xuyên suốt: skip từ có pending sync events (giữ nguyên logic hiện tại)

`addBatch()` sẽ gọi `pruneToCapSmartly()` thay vì `pruneToMostRecent()` sau insert.

**Lý do**: Mastered words đã học kỹ, không cần giữ để review. Review words với next_review_at xa (~30+ ngày) cũng không cần ngay. Giữ lại từ mới và từ cần review sớm. Không cần thêm field mới vào entity.

**Alternative**: Thêm `reviewCount` field vào `LocalWordEntity` để đếm số lần học. Rejected — cần ObjectBox code regeneration, phức tạp hơn, và `mastered` status đã capture ý nghĩa "đã học kỹ" đủ tốt.

### D4: Prune sau prefetch, không trong addBatch sẵn có
**Quyết định**: `addBatch()` đã gọi `pruneToMostRecent()`. Đổi thành gọi `pruneToCapSmartly()`. Không thêm prune call riêng trong prefetch path.
**Lý do**: DRY — prune logic đã nằm trong `addBatch()`, không cần duplicate.

## Risks / Trade-offs

- [Risk] `pruneToCapSmartly()` query study events để check pending sync → chậm hơn `pruneToMostRecent()` nếu DB lớn → Mitigation: Chỉ chạy khi total > 1000, không trên hot path của swipe.
- [Risk] Mastered words có thể bị xóa rồi backend gửi lại → word xuất hiện lại như "mới" → Acceptable: đây là behavior đúng, backend quản lý server-side state.
- [Risk] Prefetch trigger trên mỗi swipe tạo nhiều `countUnstudiedNewWords()` queries hơn → Mitigation: Query nhẹ (count only), `_prefetchInFlight` flag chặn duplicate.

## Open Questions

- Nên dùng `30 ngày` hay `14 ngày` làm ngưỡng "review xa"? → Default 30 ngày, có thể điều chỉnh trong code constant.
