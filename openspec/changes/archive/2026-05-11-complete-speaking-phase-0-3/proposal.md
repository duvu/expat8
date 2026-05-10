## Why

Phase 0-3 tháng của Speaking Foundation đã hoàn thành nền tảng kỹ thuật (recording, playback, event sync, proficiency isolation) nhưng còn 3 deliverable quan trọng chưa đạt **Definition of Done**: 3-minute drill, dashboard speaking prompt review, và weekly speaking summary. Không có những phần này, team không thể đo được adoption, không có data beta, và người dùng thiếu entry point luyện nói hằng ngày.

## What Changes

- **3-minute speaking drill**: Flow 5 prompt/session, timer nhẹ, summary tích cực sau khi hoàn thành — entry point từ home/learning screen
- **Speaking prompt management trên Dashboard**: Admin review, edit, approve/reject speaking prompt gắn với word sense
- **Weekly speaking summary API**: Backend endpoint trả về metrics tuần (spoken sentences, retry rate, first recording conversion) phục vụ mobile và analytics
- **Beta metrics instrumentation**: Track speaking funnel events đầy đủ (prompt_viewed → sample_played → recorded → self_rated → drill_completed) để có data đánh giá closed beta

## Capabilities

### New Capabilities

- `mobile-speaking-drill`: 3-minute speaking drill trên mobile — chọn 5 prompt từ recently learned/due review, record từng câu, self-rate, hiển thị summary (số câu nói, thời lượng, retry count); hoạt động offline nếu prompts đã cache
- `speaking-prompt-management`: Dashboard admin view để list, filter, edit và approve/reject speaking prompts gắn với word sense; hỗ trợ các fields: target_text, vi_hint, pronunciation_tip_vi, common_mistake_vi, difficulty, status
- `backend-speaking-analytics`: Backend endpoint `GET /v1/speaking/summary` trả weekly spoken sentences, retry rate, first recording conversion cho user/device; đồng thời expose funnel event counts cho analytics dashboard

### Modified Capabilities

- `study-events-api`: Thêm event types mới `speaking_prompt_viewed`, `speaking_sample_played`, `speaking_retried`, `speaking_self_rated_hesitated`, `speaking_self_rated_could_not_say` vào schema validation (hiện chỉ có `speaking_recorded`, `speaking_self_rated_clear`)

## Impact

- **Mobile**: Thêm DrillScreen widget, DrillSession service, prompt selection logic (ObjectBox query), summary screen
- **Backend**: Thêm `GET /v1/speaking/summary` route; mở rộng event validation cho 5 event types mới; query aggregation theo week/device
- **Dashboard (expat8-dashboard)**: Thêm `/speaking-prompts` page với table, edit form, status filter
- **Database**: Table `speaking_prompts` nếu chưa có (hoặc confirm embedded trong word_senses); aggregate view/function cho weekly metrics
- **API contract** (`contracts/api.md`): Thêm speaking summary endpoint và mở rộng event types
