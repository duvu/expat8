## Context

Hiện tại hệ thống hoạt động như sau:

- **Backend LLM batch**: `generation_service.js` gọi LLM với `limit = 5` (default). Mỗi lần cần từ mới, backend sinh tối đa 5 từ mỗi vòng (retry tối đa 3 lần = 15 từ tối đa).
- **Mobile prefetch**: `vocabPrefetchLimit` default là **10** từ mỗi lần gọi backend. Mobile đã có watermark-based trigger (threshold `vocabProactiveThreshold = 100`, `vocabProactiveMinNew = 10`) và `prefetchBatch(batchSize: 100)` nhưng config default lại dùng 10.
- **Mobile user activity**: `_triggerPrefetchIfNeeded()` chạy khi local unlearned count ≤ 3 — đây là offline-first đúng. Tuy nhiên `vocabPrefetchLimit = 10` nên mỗi lần chỉ tải 10 từ.
- **Backend endpoint**: `POST /v1/learning/cards` đã hỗ trợ `limit` tối đa 100 (via `clampLimit(body.limit, 1, 100)`).

Vấn đề cốt lõi: config mặc định quá nhỏ (5 cho LLM, 10 cho mobile), khiến kho từ nạp chậm và phải gọi backend/LLM liên tục.

## Goals / Non-Goals

**Goals:**
- Backend LLM mỗi lần gọi sinh đủ 100 từ
- Mobile mỗi lần tải batch 100 từ từ backend
- User learning activities (swipe, rating) chỉ đọc/ghi local ObjectBox, không gọi backend
- Watermark trigger hiện có giữ nguyên logic; chỉ tăng batch size

**Non-Goals:**
- Thay đổi API contract (endpoint `/v1/learning/cards` giữ nguyên)
- Thay đổi retry/fallback logic hiện có
- Implement sync study events (đã có, giữ nguyên)
- Thay đổi ObjectBox entity schema

## Decisions

### D1: Tăng LLM batch size lên 100 trong generation_service.js

**Quyết định**: Thay đổi default `limit = 5` thành `limit = 100` trong `generation_service.js`.

**Rationale**: Gọi LLM với 100 từ một lần rẻ hơn 20 lần gọi với 5 từ về cả latency và cost. Backend đã có retry loop (3 lần) và validation — với batch lớn hơn, số từ hợp lệ per LLM call tăng đáng kể.

**Alternatives considered**:
- Tạo config env var `LLM_GENERATION_BATCH_SIZE`: Phức tạp hơn mà không cần thiết — 100 là giá trị tốt nhất cho use case này.

### D2: Tăng mobile vocabPrefetchLimit default lên 100

**Quyết định**: Đổi `defaultValue: 10` thành `defaultValue: 100` cho `VOCAB_PREFETCH_LIMIT` trong `config.dart`.

**Rationale**: Code đã đúng (`prefetchBatch(batchSize: 100)` clamp max 100), chỉ cần thay đổi config default. Không cần refactor code.

**Alternatives considered**:
- Hardcode 100 vào `prefetchBatch()`: Ít flexible hơn; giữ configurable là tốt.

### D3: Giữ nguyên watermark trigger, không thay đổi user activity flow

**Quyết định**: Không thay đổi `_triggerPrefetchIfNeeded()` hay gesture handlers. User activities (swipe) chỉ đọc/ghi local ObjectBox — đây đã là behavior hiện tại (PUT /v1/user-word-cache là background sync, không block UI).

**Rationale**: Codebase đã offline-first: swipe gọi `onSwipeRightToLeft()` → đọc next word từ local ObjectBox. Backend chỉ được gọi khi `count <= 3` (low watermark). Chỉ cần tăng batch size là đủ.

**Alternatives considered**:
- Tăng low watermark threshold từ 3 lên cao hơn: Có thể làm nhưng không thuộc scope này.

### D4: Không thay đổi clamp limit ở endpoint

**Quyết định**: Backend endpoint `/v1/learning/cards` đã `clampLimit(body.limit, 1, 100)` — đúng rồi. Không cần thay đổi.

## Risks / Trade-offs

| Risk | Mitigation |
|---|---|
| LLM prompt 100 từ có thể vượt token limit | Kiểm tra prompt size trong `litellm_client.js`; 100 từ JSON ~5KB — trong giới hạn của hầu hết model. |
| LLM trả về ít hơn 100 từ hợp lệ | Retry loop (3 lần) đã xử lý; kết quả partial vẫn được lưu và serve. |
| Mobile download 100 từ làm tăng network payload | ~100 từ × ~500 bytes = ~50KB — không đáng kể trên mobile network. |
| Startup lần đầu của user tải 100 từ chậm hơn trước | Acceptable — tradeoff với ít lần gọi backend hơn về sau. |

## Migration Plan

1. Deploy backend change (tăng `limit = 100` trong `generation_service.js`)
2. Release mobile build mới với `vocabPrefetchLimit = 100`
3. Rollback: revert config changes về giá trị cũ — không có schema migration, fully reversible.

## Open Questions

- Cần kiểm tra xem LLM prompt hiện tại có handle được 100 từ tốt không (quality check).
- Có muốn tăng low-watermark trigger từ `count <= 3` lên cao hơn (ví dụ `count <= 20`) để đảm bảo prefetch sớm hơn khi có batch lớn không?
