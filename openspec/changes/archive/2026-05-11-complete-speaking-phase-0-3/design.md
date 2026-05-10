## Context

Phase 0-3 tháng Speaking Foundation đã ship nền tảng kỹ thuật cốt lõi: local audio recording/playback, speaking study events, proficiency isolation, và release APK. Còn lại 3 deliverable quan trọng để đạt **Definition of Done** theo tài liệu `20260509-expat8-phase-0-3-speaking-foundation.md`:

1. **3-minute speaking drill** (Slice 5) — entry point luyện nói hằng ngày
2. **Dashboard speaking prompt management** — content team review/approve prompts
3. **Weekly speaking summary + beta metrics** — đo adoption, first recording conversion

Backend hiện tại: Node.js 22 + Express, PostgreSQL, study events outbox đã có. Mobile: Flutter + ObjectBox, speaking events outbox đã hoạt động.

## Goals / Non-Goals

**Goals:**
- Implement 3-minute drill flow trên mobile (5 prompts, record, self-rate, summary)
- Thêm speaking prompt review UI vào expat8-dashboard (Next.js)
- Expose `GET /v1/speaking/summary` endpoint cho weekly metrics
- Mở rộng event validation để nhận đủ 7 speaking event types
- Có đủ data để chạy closed beta và đo first recording conversion

**Non-Goals:**
- AI pronunciation scoring
- Backend audio storage hoặc upload
- Real-time feedback
- Public voice community
- Subscription/paywall

## Decisions

### Decision 1: 3-minute drill dùng lại ObjectBox query hiện có, không cần API mới

**Rationale**: Mobile đã có `SpeakingPrompt` entity trong ObjectBox (hoặc embedded trong word sense). Drill chọn 5 prompts từ local cache dựa trên `last_learned_at` và `due_review_at`. Offline-first phù hợp với kiến trúc hiện tại.

**Alternative considered**: Fetch 5 prompts từ backend mỗi lần drill. Bị loại vì: thêm latency, phá offline-first principle, complex session state management.

**Chosen**: `DrillSession` service query ObjectBox locally, sort by `(review_due DESC, learned_at DESC)`, take 5. Nếu không đủ 5 prompt, fallback về recently learned words.

### Decision 2: Speaking summary API dùng aggregate query từ study_events table

**Rationale**: Speaking events đã được lưu trong `study_events` table (event_type IN ('speaking_recorded', 'speaking_self_rated_*', ...)). Không cần bảng riêng — chỉ cần aggregate query theo `(device_id, week)`.

**Alternative considered**: Materialized view / separate analytics table. Overkill cho beta scale, có thể thêm sau khi volume tăng.

**Chosen**: Raw aggregate query, cache result 1 giờ in-memory. Query: `COUNT(DISTINCT attempt_id) WHERE event_type='speaking_recorded' AND created_at > now()-7days GROUP BY device_id`.

### Decision 3: Dashboard dùng REST call trực tiếp tới backend `/v1/admin/speaking-prompts`

**Rationale**: `expat8-dashboard` là Next.js app đã có pattern gọi backend API. Thêm speaking prompt CRUD vào existing admin API pattern.

**Alternative considered**: Truy cập DB trực tiếp từ dashboard server-side. Bị loại vì vi phạm separation of concerns và không có auth layer.

**Chosen**: New admin route `GET|PUT /v1/admin/speaking-prompts` với app-credential auth. Dashboard gọi qua server-side API route (Next.js API routes).

### Decision 4: speaking_prompts là bảng riêng, không embed vào word_senses

**Rationale**: Một word sense có thể có nhiều speaking prompts (different difficulty/topic). Normalize tốt hơn, dễ quản lý qua dashboard, dễ thêm fields sau.

**Alternative considered**: JSON field trong word_senses. Bị loại vì không query được efficiently, dashboard edit sẽ phức tạp.

**Chosen**: Table `speaking_prompts(id, word_sense_id, target_text, vi_hint, pronunciation_tip_vi, common_mistake_vi, difficulty, topic, status, created_at, updated_at)`.

## Risks / Trade-offs

- **[Risk] Prompt chất lượng thấp trong beta** → Mitigation: Dashboard checklist, bắt đầu với 50-200 curated prompts, admin review trước khi approve
- **[Risk] ObjectBox query performance nếu local store lớn** → Mitigation: Index trên `word_sense_id`, limit query scan tới 100 candidates
- **[Risk] Weekly summary query chậm khi event table lớn** → Mitigation: Index trên `(device_id, event_type, created_at)`, TTL cache 1 giờ
- **[Risk] Drill UI làm gián đoạn swipe session hiện có** → Mitigation: Drill là optional entry point riêng, không inject vào swipe flow; gentle prompt sau 3 swipe sessions

## Migration Plan

1. **Backend migration**: Thêm `speaking_prompts` table via new migration file; backfill 50 seed prompts; index `study_events(device_id, event_type, created_at)`
2. **Backend API**: Deploy `GET /v1/speaking/summary` và admin prompt routes sau migration
3. **Dashboard**: Deploy speaking prompt management page sau backend routes live
4. **Mobile**: Drill screen behind existing `SPEAKING_FOUNDATION_ENABLED` feature flag; no migration needed (reads from ObjectBox)
5. **Rollback**: Feature flag `SPEAKING_FOUNDATION_ENABLED=false` disables drill UI; backend routes are additive (no breaking changes)

## Open Questions

- Speaking prompts seed data: ai tạo 50 prompts đầu tiên (content team hay LLM + human review)?
- Weekly summary window: calendar week vs. rolling 7 days? (đề xuất: rolling 7 days, đơn giản hơn)
- Mobile drill entry point: home screen widget hay từ learning session end screen?
- Prompt selection algorithm: nếu user chưa có recently learned words, dùng global default prompts hay yêu cầu học từ trước?
