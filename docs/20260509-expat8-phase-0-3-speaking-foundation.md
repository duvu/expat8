# Expat8 Phase 0-3 Months: Speaking Foundation

## Mục Đích

Tài liệu này chi tiết hóa giai đoạn 0-3 tháng đầu trong roadmap 2026-2028 của Expat8.

Mục tiêu của giai đoạn này là chuyển Expat8 từ trải nghiệm học từ vựng thuần flashcard sang một vòng luyện nói tối thiểu nhưng đo được:

```text
See word/phrase -> Listen -> Repeat -> Hear yourself -> Self-rate -> Continue
```

Giai đoạn này chưa cần AI pronunciation scoring phức tạp. Thành công trước mắt là khiến người học Việt Nam **bắt đầu mở miệng nói tiếng Anh đều đặn**, ít sợ hơn, và có dữ liệu nền để các giai đoạn sau cá nhân hóa feedback.

## Bối Cảnh Hiện Có

Expat8 hiện có nền tảng phù hợp để thêm speaking foundation:

- Mobile Flutter app có learning session offline-first, swipe gestures, ObjectBox local storage và study event outbox.
- Backend có user/session, app credential signing, study events, proficiency tracking và learning cards API.
- Content ingestion pipeline đang hướng tới article -> terms -> word senses -> review -> publish.
- Dashboard Next.js có thể review article/vocabulary và mở rộng để quản lý speaking prompt.
- OpenSpec đang có active change `content-ingestion-v2-foundation`, liên quan trực tiếp đến article/vocabulary pipeline.

Điểm còn thiếu:

- Chưa có audio recording/playback flow trong mobile.
- Chưa có concept speaking prompt hoặc speaking attempt trong contract.
- Chưa có metric speaking minutes, spoken sentences, retry rate hoặc self-confidence.
- Chưa có content QA riêng cho câu nói tự nhiên và lỗi thường gặp của người Việt.

## Product Thesis

Người Việt thường không thiếu ý chí học tiếng Anh, nhưng dễ bị kẹt ở 3 điểm:

- Biết từ nhưng không bật được câu.
- Sợ phát âm sai nên tránh nói.
- Không có vòng luyện nói nhỏ, riêng tư, lặp lại hằng ngày.

Vì vậy, 0-3 tháng đầu nên tối ưu cho một trải nghiệm rất nhỏ:

```text
Tôi học một từ/cụm từ -> Tôi nghe câu mẫu -> Tôi nói lại -> Tôi nghe chính mình -> Tôi thấy hôm nay mình đã nói được.
```

Không cần tạo cảm giác như lớp học. Cần tạo cảm giác như một người bạn nhắc người học nói 3 phút mỗi ngày.

## North Star Cho Giai Đoạn 0-3 Tháng

**Số câu tiếng Anh người học đã nói thành tiếng mỗi tuần.**

Metric này phù hợp hơn `accuracy` trong giai đoạn đầu vì mục tiêu là xây thói quen và sự tự tin.

Metrics phụ:

- First recording conversion: tỷ lệ người học active có ít nhất 1 bản ghi âm.
- Weekly spoken sentences: số câu nói/tuần/user.
- Repeat rate: tỷ lệ câu được ghi âm lại ít nhất 1 lần.
- Self-confidence delta: người học tự đánh giá tự tin hơn sau 7 ngày.
- Speaking streak: số ngày liên tiếp có ít nhất 1 speaking action.

## Người Dùng Mục Tiêu

### Persona 1: Người mất gốc nhưng muốn nói được câu ngắn

- Trình độ: A1-A2.
- Nỗi sợ: phát âm sai, không biết nói câu nào.
- Cần: câu ngắn, có nghĩa tiếng Việt, có phát âm dễ bắt chước, không bị chấm điểm gắt.

### Persona 2: Người đi làm cần nói công việc cơ bản

- Trình độ: A2-B1.
- Nỗi sợ: họp, giới thiệu tiến độ, hỏi lại khi không hiểu.
- Cần: cụm từ thực tế, câu mẫu công sở, luyện phản xạ ngắn.

### Persona 3: Người học đều nhưng chỉ học thầm

- Trình độ: bất kỳ.
- Nỗi sợ: ngại nghe lại giọng mình.
- Cần: private recording, retry dễ, feedback nhẹ, không public.

## Scope Sản Phẩm

### In Scope

- Speaking card mode trên vocabulary card hiện có.
- Audio recording và playback cục bộ trên mobile.
- Câu mẫu nói tự nhiên cho mỗi từ/cụm từ ưu tiên.
- Mini-drill 3 phút gồm 5 câu nói ngắn.
- Self-rating sau speaking attempt.
- Speaking study events sync về backend.
- Dashboard fields để review speaking prompt và common Vietnamese mistake.
- Analytics cơ bản cho speaking funnel.

### Out Of Scope Trong 0-3 Tháng

- Realtime AI conversation.
- AI pronunciation scoring tự động.
- Speech-to-text bắt buộc.
- Public voice community.
- Human coach review.
- Subscription/paywall.
- Gamification phức tạp.
- Mở rộng ngôn ngữ ngoài tiếng Anh cho speaking.

## Core Experience

### Mobile Flow 1: Speaking Card

```text
┌──────────────────────────────────────────────┐
│ Vocabulary Card                              │
│                                              │
│ reliable                                     │
│ meaning: đáng tin cậy                        │
│ IPA: /rɪˈlaɪəbl/                             │
│ example: She is a reliable teammate.         │
│                                              │
│ [Listen] [Speak] [Hear Myself]               │
└──────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────┐
│ Repeat Mode                                  │
│                                              │
│ Say: She is a reliable teammate.             │
│ Hint VI: Cô ấy là đồng đội đáng tin cậy.     │
│                                              │
│ Hold to record / Tap to stop                 │
└──────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────┐
│ Review Yourself                              │
│                                              │
│ [Play Mine] [Try Again]                      │
│                                              │
│ How did it feel?                             │
│ [Clear] [Hesitated] [Could not say it]       │
└──────────────────────────────────────────────┘
```

Key idea: người học tự nghe lại trước khi app đánh giá. Đây là bước rất quan trọng để giảm sợ nói.

### Mobile Flow 2: 3-Minute Speaking Drill

```text
Start drill
  │
  ├─ Select 5 cards from recently learned / due review / useful phrases
  │
  ├─ For each card:
  │     Listen sample
  │     Record sentence
  │     Self-rate
  │
  └─ End summary:
        5 sentences spoken
        2 retried
        3 clear
        2 hesitated
```

Drill nên có cảm giác nhẹ:

- Không bắt buộc hoàn hảo.
- Không chấm điểm đỏ/xanh quá mạnh.
- Có thể bỏ qua câu khó.
- Có summary tích cực: `Bạn đã nói 5 câu hôm nay.`

### Mobile Flow 3: Review From Existing Swipe Session

Không nên phá gesture learning hiện có. Speaking mode nên là lớp bổ sung:

```text
Normal swipe session
  │
  ├─ See vocabulary card
  │
  ├─ Optional: tap Speak
  │
  ├─ Record local speaking action
  │
  └─ Continue swipe flow
```

Nếu speaking bắt buộc ngay từ đầu, retention có thể giảm. Nên dùng gentle prompt:

```text
Bạn đã học từ này 3 lần. Thử nói một câu với nó?
```

## Content Model Đề Xuất

Hiện vocabulary card có term, meaning, pronunciation, IPA, example và translation. Speaking cần thêm metadata phục vụ nói.

### Speaking Prompt Fields

Tên bảng hoặc entity có thể là `speaking_prompts` ở backend, hoặc embedded metadata trong `word_senses` nếu muốn giảm scope ban đầu.

Fields đề xuất:

| Field | Ý nghĩa |
|---|---|
| `id` | ID prompt |
| `word_sense_id` | Liên kết với sense đang học |
| `article_term_id` | Optional, nếu prompt lấy từ article context |
| `target_text` | Câu tiếng Anh người học cần nói |
| `vi_hint` | Gợi ý tiếng Việt |
| `target_phrase` | Từ/cụm từ trọng tâm |
| `pronunciation_tip_vi` | Mẹo phát âm ngắn cho người Việt |
| `common_mistake_vi` | Lỗi thường gặp, ví dụ bỏ âm cuối |
| `difficulty` | CEFR target |
| `topic` | Chủ đề: work, daily, travel, interview |
| `status` | pending_review, approved, rejected |
| `created_at` | Timestamp |
| `updated_at` | Timestamp |

### Content Quality Rules

- Câu phải ngắn hơn 12 từ cho A1-A2.
- Câu phải tự nhiên, có thể dùng trong đời sống thật.
- Không dùng ví dụ quá văn viết nếu mục tiêu là speaking.
- Có bản gợi ý tiếng Việt nhưng không khuyến khích dịch từng chữ.
- Ưu tiên câu có thể nói độc lập, không cần nhiều context.

Ví dụ tốt:

| Term | Prompt | VI hint | Why good |
|---|---|---|---|
| reliable | She is a reliable teammate. | Cô ấy là đồng đội đáng tin cậy. | Ngắn, tự nhiên, công việc |
| reschedule | Can we reschedule the meeting? | Mình dời lịch họp được không? | Rất hữu dụng cho công sở |
| get used to | I am getting used to this job. | Tôi đang quen dần với công việc này. | Cụm từ giao tiếp thật |

Ví dụ không nên ưu tiên:

| Prompt | Lý do |
|---|---|
| The reliable infrastructure underpins economic resilience. | Quá học thuật cho speaking giai đoạn đầu |
| This word means reliable. | Không phải câu giao tiếp thật |
| I reliable my teammate. | Sai cấu trúc, không nên làm prompt mẫu |

## Speaking Event Model

Giai đoạn 0-3 tháng nên tận dụng study event architecture hiện có thay vì tạo hệ thống tracking hoàn toàn riêng.

### Event Types Đề Xuất

| Event type | Khi nào ghi |
|---|---|
| `speaking_prompt_viewed` | Người học mở speaking prompt |
| `speaking_sample_played` | Người học nghe câu mẫu |
| `speaking_recorded` | Người học ghi âm một câu |
| `speaking_retried` | Người học ghi âm lại cùng prompt |
| `speaking_self_rated_clear` | Người học tự đánh giá nói rõ |
| `speaking_self_rated_hesitated` | Người học tự đánh giá bị ngập ngừng |
| `speaking_self_rated_could_not_say` | Người học không nói được |

### Attempt Metadata

Không cần upload audio trong MVP nếu privacy/cost chưa sẵn sàng. Nhưng cần lưu metadata:

| Field | Ý nghĩa |
|---|---|
| `attempt_id` | Local UUID, sync idempotent |
| `prompt_id` | Speaking prompt |
| `word_sense_id` | Vocabulary link |
| `duration_ms` | Độ dài bản ghi |
| `retry_count` | Lần thử thứ mấy |
| `self_rating` | clear, hesitated, could_not_say |
| `created_at` | Local timestamp |
| `synced_at` | Backend sync timestamp |

### Audio Retention Giai Đoạn Đầu

Đề xuất mặc định:

- Audio lưu local-only trong 7 ngày.
- Người học có nút xóa tất cả bản ghi local.
- Không upload audio lên backend trong 0-3 tháng, trừ khi có opt-in rõ ràng cho thử nghiệm nội bộ.
- Backend chỉ nhận metadata và study events.

Lý do:

- Giảm rủi ro privacy.
- Giảm chi phí storage và bandwidth.
- Vẫn đo được adoption của speaking loop.
- Chuẩn bị dữ liệu cho giai đoạn 3-6 tháng khi thêm AI feedback.

## API Và Contract Đề Xuất

### Option A: Mở Rộng Study Events Hiện Có

Đây là hướng ít rủi ro nhất.

```text
POST /v1/study-events
```

Payload thêm event types speaking và metadata JSON.

Ưu điểm:

- Tận dụng sync/outbox/idempotency hiện có.
- Không mở API surface quá lớn.
- Phù hợp phase 0-3 vì chưa xử lý audio backend.

Nhược điểm:

- Cần đảm bảo event schema đủ linh hoạt nhưng không lỏng quá.
- Analytics speaking có thể cần view/materialized query riêng.

### Option B: API Riêng Cho Speaking Attempts

```text
POST /v1/speaking/attempts
GET /v1/speaking/summary
```

Ưu điểm:

- Tách domain speaking rõ hơn.
- Dễ phát triển AI feedback sau này.

Nhược điểm:

- Nhiều việc hơn trong 0-3 tháng.
- Dễ trùng logic sync với study events.

### Recommendation

Trong 0-3 tháng, chọn Option A. Chỉ chuẩn bị tên miền `speaking_attempt` trong event metadata để sau này migrate sang API riêng nếu cần.

## Dashboard Scope

Dashboard không cần thành CMS lớn. Chỉ cần bổ sung đủ để content team review speaking prompt.

### Dashboard Views

| View | Chức năng |
|---|---|
| Vocabulary review | Hiển thị prompt speaking gắn với word sense |
| Prompt editor | Sửa target text, vi hint, pronunciation tip, common mistake |
| Prompt status | pending_review, approved, rejected |
| Prompt quality queue | Lọc prompt thiếu hint, quá dài, chưa approved |

### Review Checklist Cho Prompt

- Câu có dùng đúng từ/cụm từ trọng tâm không?
- Câu có nói được trong đời thật không?
- Có quá dài so với level không?
- Gợi ý tiếng Việt có tự nhiên không?
- Có lỗi phát âm người Việt hay gặp để nhắc không?
- Có tránh nội dung nhạy cảm hoặc quá riêng tư không?

## Mobile UX Principles

### Low Pressure

Không dùng ngôn ngữ gây xấu hổ:

- Không nên: `Sai rồi`, `Phát âm kém`, `Bạn nói chưa chuẩn`.
- Nên: `Thử lại chậm hơn`, `Câu này hơi khó`, `Bạn đã nói được một câu hôm nay`.

### Private By Default

- Nói rõ bản ghi chỉ lưu trên máy trong giai đoạn đầu.
- Có nút xóa bản ghi.
- Không tự động upload audio.

### Tiny Wins

Mỗi speaking session nên kết thúc bằng một thành tựu nhỏ:

```text
Bạn đã nói 5 câu hôm nay.
Bạn đã luyện 2 phút 40 giây.
Bạn đã thử lại 3 lần. Đây là cách tiến bộ thật.
```

### Do Not Break Swipe

Swipe session hiện là trải nghiệm cốt lõi. Speaking phải là optional entry point hoặc gentle prompt, không làm card navigation chậm.

## Implementation Slices

### Slice 1: Speaking Prompt Data Available

Goal: app có dữ liệu câu nói để hiển thị.

Work items:

- Xác định schema prompt tối thiểu.
- Thêm prompt vào seed/test content hoặc API response.
- Dashboard hiển thị prompt read-only trước.
- Contract update cho card payload nếu cần.

Acceptance criteria:

- Một vocabulary card có thể hiển thị `target_text` và `vi_hint`.
- Không ảnh hưởng card loading hiện có.
- Nếu prompt thiếu, app fallback về example sentence hiện có.

### Slice 2: Local Audio Record And Playback

Goal: người học ghi âm và nghe lại chính mình.

Work items:

- Chọn Flutter plugin audio recording/playback.
- Xin quyền microphone rõ ràng.
- Ghi file audio local theo attempt id.
- Playback bản ghi gần nhất.
- Xóa bản ghi theo prompt hoặc xóa tất cả.

Acceptance criteria:

- Android release build ghi âm/playback ổn định.
- App không crash khi user từ chối microphone permission.
- File audio không bị sync/upload ngoài ý muốn.

### Slice 3: Speaking Self-Rating

Goal: người học tự đánh giá sau khi nói.

Work items:

- UI rating: clear, hesitated, could_not_say.
- Lưu local attempt metadata.
- Ghi study event tương ứng.
- Show encouraging summary.

Acceptance criteria:

- Mỗi recording có tối đa một self-rating active.
- Retry cùng prompt tăng retry count.
- Offline vẫn lưu được attempt và event.

### Slice 4: Sync Speaking Events

Goal: backend nhận được hành vi speaking không kèm audio.

Work items:

- Mở rộng study event validation để nhận speaking event types.
- Lưu metadata an toàn, không chứa audio path nhạy cảm.
- Idempotency theo attempt/event id.
- Backend summary query cho weekly speaking metrics.

Acceptance criteria:

- Event sync không phá rating/proficiency hiện có.
- Duplicate event không nhân đôi speaking count.
- Backend có thể trả weekly count cơ bản cho user/device.

### Slice 5: 3-Minute Drill

Goal: tạo session nói ngắn, có thể dùng hằng ngày.

Work items:

- Chọn 5 prompt từ recently learned/due review.
- Timer nhẹ hoặc progress 1/5, 2/5.
- End summary.
- Entry point từ home/learning screen.

Acceptance criteria:

- Người học có thể hoàn thành drill dưới 3 phút.
- Drill hoạt động offline nếu prompts đã cache.
- Summary hiển thị số câu nói, thời lượng, retry count.

## Milestone Plan 12 Tuần

| Tuần | Milestone | Output |
|---|---|---|
| 1 | Product/spec alignment | OpenSpec proposal cho speaking foundation, event taxonomy, privacy decision |
| 2 | Content model spike | Prompt fields, dashboard wireframe, sample prompt set 50 câu |
| 3 | Mobile audio spike | Plugin chosen, permission flow, local record/playback prototype |
| 4 | Card UI integration | Speaking panel trên vocabulary card behind feature flag |
| 5 | Local attempt storage | ObjectBox/local file retention, retry count, delete flow |
| 6 | Self-rating events | clear/hesitated/could_not_say local events |
| 7 | Backend event validation | Speaking event types accepted and persisted |
| 8 | Sync hardening | Offline queue, idempotency, tests |
| 9 | Dashboard prompt review | Edit/review prompt fields for admin |
| 10 | 3-minute drill | 5-prompt drill, summary screen |
| 11 | Analytics and QA | Funnel metrics, device permission QA, release candidate |
| 12 | Beta rollout | Internal/beta users, measure first recording conversion |

## Suggested OpenSpec Changes

Sau exploration này, nên tạo một OpenSpec change riêng, ví dụ:

```text
add-speaking-foundation
```

Capabilities có thể cần spec:

- `mobile-speaking-session`
- `speaking-study-events`
- `speaking-prompt-review`
- `audio-privacy-retention`

Spec requirements nên capture:

- Mobile SHALL allow local record/playback for speaking prompts.
- Mobile SHALL keep audio local-only by default in phase 0-3.
- Backend SHALL accept speaking study events without audio payload.
- Dashboard SHALL allow approved admins to review speaking prompts.
- System SHALL expose weekly speaking summary metrics.

## Analytics Plan

### Funnel Events

```text
learning_card_viewed
  -> speaking_prompt_viewed
  -> speaking_sample_played
  -> microphone_permission_requested
  -> speaking_recorded
  -> speaking_retried
  -> speaking_self_rated
  -> speaking_drill_completed
```

### Dashboard Metrics

| Metric | Why it matters |
|---|---|
| First recording conversion | Người học có vượt qua nỗi ngại ban đầu không |
| Recordings per active learner | Speaking loop có được dùng thường xuyên không |
| Retry rate | Người học có tự sửa không |
| Could-not-say rate by prompt | Prompt nào quá khó |
| Drill completion rate | 3-minute flow có vừa sức không |
| Audio permission denial rate | UX xin quyền có gây sợ không |

## QA Matrix

| Area | Cases |
|---|---|
| Permission | grant, deny, deny permanently, revoke after grant |
| Offline | record offline, rate offline, sync later |
| Storage | many recordings, delete one, delete all, app restart |
| Playback | speaker, headset, interrupted by phone/audio focus |
| Sync | duplicate event, network failure, auth expired |
| UX | card without prompt, prompt too long, quick retry, back navigation |
| Privacy | no audio in backend payload, no accidental logs of local file path |

## Risks Và Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Người học ngại bấm record | Core loop fail | Gentle entry, private-by-default, no harsh scoring |
| Audio plugin edge cases | Mobile instability | Spike early, test Android/iOS, keep feature flag |
| Prompt chất lượng thấp | Người học thấy vô dụng | Dashboard review checklist, start with curated 50-200 prompts |
| Thêm speaking làm swipe chậm | Retention giảm | Speaking optional, card selection không await network |
| Privacy concern | Trust loss | Local-only audio, delete controls, clear copy |
| Event schema quá lỏng | Analytics khó dùng | Define fixed event types and typed metadata |

## Beta Rollout Plan

### Internal Alpha

- 10-20 người nội bộ hoặc người quen.
- Mục tiêu: phát hiện crash, permission issue, recording UX issue.
- Không quan tâm retention vội.

### Closed Beta

- 50-100 người Việt đang học nói tiếng Anh.
- Chia theo A1-A2 và B1.
- Theo dõi first recording conversion, retry rate, weekly spoken sentences.

### Public Soft Launch

- Feature flag bật dần.
- Chỉ bật cho English learning session.
- Không quảng bá là AI scoring, chỉ quảng bá là luyện nói riêng tư mỗi ngày.

## Definition Of Done Cho Giai Đoạn 0-3 Tháng

Giai đoạn này được xem là hoàn thành khi:

- Người học có thể ghi âm và nghe lại câu tiếng Anh gắn với vocabulary card.
- App ghi nhận speaking self-rating và sync metadata lên backend.
- Có 3-minute drill hoạt động offline với prompt đã cache.
- Dashboard có cách review và approve speaking prompts.
- Có weekly speaking summary cơ bản.
- Audio mặc định không upload lên backend.
- Có số liệu beta cho first recording conversion, weekly spoken sentences và retry rate.

## Quyết Định Sản Phẩm Quan Trọng

### Decision 1: No AI scoring in the first 3 months

Lý do:

- Giảm complexity.
- Tránh feedback sai làm người học mất tự tin.
- Tập trung đo adoption của speaking behavior.

### Decision 2: Audio local-only by default

Lý do:

- Tạo trust.
- Giảm chi phí.
- Tránh xử lý privacy quá sớm.

### Decision 3: Speaking should augment, not replace, flashcards

Lý do:

- Learning session hiện đã hoạt động theo offline-first/swipe pattern.
- Nếu ép người học nói quá sớm, có thể giảm usage.

### Decision 4: Start with curated prompt quality

Lý do:

- Người học cần câu tự nhiên, không phải output LLM chưa review.
- 50-200 prompt tốt có giá trị hơn 5.000 prompt trung bình.

## Open Questions

- Audio recording plugin nào phù hợp nhất với Flutter target hiện tại?
- Có cần TTS câu mẫu ngay phase 0-3, hay dùng device TTS trước?
- Speaking prompt nên là bảng riêng hay field mở rộng trong content model hiện có?
- Weekly summary nằm trong mobile local analytics, backend API, hay cả hai?
- Prompt đầu tiên nên tập trung vào công sở, daily life, hay onboarding theo goal?
- Có cần opt-in upload audio cho internal beta để chuẩn bị AI scoring phase 3-6 không?

## Recommended Next Step

Từ exploration này, bước tốt nhất là tạo OpenSpec proposal `add-speaking-foundation` với scope nhỏ:

```text
Phase 0-3 deliverable:
  local audio speaking card
  speaking self-rating events
  prompt review fields
  3-minute drill
  weekly speaking summary
```

Không nên bắt đầu bằng realtime AI coach. AI coach là giai đoạn 12-18 tháng. Giai đoạn 0-3 tháng chỉ cần chứng minh: người Việt có chịu nói nhiều hơn khi app tạo một vòng luyện nói riêng tư, nhẹ, và gắn với từ/cụm từ họ vừa học hay không.
