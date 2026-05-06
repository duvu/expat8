## 1. Backend: Tăng LLM batch size lên 100

- [x] 1.1 Trong `backend/src/generation_service.js`, thay đổi default parameter `limit = 5` thành `limit = 100`
- [x] 1.2 Kiểm tra LLM prompt trong `backend/src/litellm_client.js` — đảm bảo prompt handle được 100 từ (không có hardcoded limit nhỏ trong prompt text)
- [x] 1.3 Test thủ công: gọi `POST /v1/learning/cards` với `limit=100` khi kho từ trống để trigger LLM generation và verify backend sinh đủ batch lớn

## 2. Mobile: Tăng vocabPrefetchLimit default lên 100

- [x] 2.1 Trong `mobile/lib/src/config.dart`, thay đổi `defaultValue: 10` thành `defaultValue: 100` cho `VOCAB_PREFETCH_LIMIT`
- [x] 2.2 Verify `vocabulary_refresh_worker.dart` và `word_repository.dart` sử dụng `_config.vocabPrefetchLimit` đúng — không hardcode limit nhỏ nào khác trong prefetch flow

## 3. Verification

- [x] 3.1 Chạy backend smoke test: `node scripts/smoke-deployed-backend.mjs` — tất cả PASS
- [x] 3.2 Build và chạy mobile app trên emulator với `VOCAB_PREFETCH_LIMIT` không set (dùng default 100) — verify backend log nhận `POST /v1/learning/cards` với limit=100
- [x] 3.3 Kiểm tra app hoạt động bình thường: swipe cards, không có backend call trong lúc swipe (chỉ có PUT /v1/user-word-cache định kỳ)
- [x] 3.4 Kiểm tra Logs screen trên app — không có "Backend new-word request failed" sau khi prefetch 100 từ thành công
