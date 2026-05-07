## Why

Hiện tại mỗi lần cần từ mới, mobile app gọi backend 1 từ một lần và backend gọi LLM để sinh ít từ, dẫn đến trải nghiệm chậm, phụ thuộc mạng liên tục, và API rate pressure cao. Người dùng cần trải nghiệm học liên tục mượt mà kể cả khi offline hoặc mạng yếu.

## What Changes

- **Backend**: Mỗi lần gọi LLM, backend phải yêu cầu đủ **100 từ** trong một batch duy nhất để tối đa hóa hiệu quả và lấp đầy kho từ nhanh hơn.
- **Backend**: Endpoint `POST /v1/learning/cards` trả về tối đa **100 từ** trong một lần gọi khi mobile yêu cầu.
- **Mobile**: Khi cần tải từ, app yêu cầu batch **100 từ** và lưu toàn bộ vào ObjectBox local DB.
- **Mobile**: Mọi hoạt động học tập của người dùng (swipe, rating, trả lời) chỉ đọc/ghi từ **local ObjectBox DB**, không gọi backend.
- **Mobile**: Backend chỉ được gọi khi: (1) local DB có ít hơn ngưỡng từ chưa học, (2) sync study events lên backend (background).
- Xóa logic "gọi backend mỗi swipe" hiện có hoặc làm cho nó không chạy với user activity.

## Capabilities

### New Capabilities
- `backend-llm-batch-generation`: Backend sinh 100 từ mỗi lần gọi LLM, lưu vào DB và phục vụ từ kho.
- `mobile-offline-first-learning`: Mobile tải 100 từ một batch, lưu local, học hoàn toàn offline từ local DB.

### Modified Capabilities
- `ai-vocabulary-generation`: Batch size thay đổi từ nhỏ lẻ lên 100 từ mỗi lần gọi LLM.
- `mobile-local-cache-sync`: Trigger tải batch mới khi local DB dưới ngưỡng, không gọi backend theo từng user action.
- `backend-word-feed-sync`: Endpoint hỗ trợ trả về batch tối đa 100 từ thay vì giới hạn nhỏ.

## Impact

- **Backend**: `generation_service.js` — tăng `requestedCount` lên 100; `app.js` hoặc endpoint handler cho `/v1/learning/cards` — cho phép `limit` tối đa 100.
- **Mobile**: `learning_session_controller.dart` — thay đổi logic trigger tải từ (từ per-swipe sang low-watermark); `LearningCardsRepository` hoặc tương đương — batch size = 100.
- **API contract**: `limit` trong `POST /v1/learning/cards` cho phép tối đa 100 (hiện là bao nhiêu cần kiểm tra).
- **Không breaking**: Existing API signature giữ nguyên, chỉ thay đổi giá trị limit được phép và internal batch size.
