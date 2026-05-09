# Expat8 Product Roadmap 2026-2028

## Tầm Nhìn

Mục đích tối thượng của Expat8 là giúp người Việt **nói tiếng Anh tự tin trong đời sống thật**, không chỉ nhớ từ vựng hay làm bài tập đúng.

Trong 1-2 năm tới, Expat8 nên chuyển trọng tâm từ một ứng dụng học từ vựng offline-first thành một **AI speaking coach cá nhân hóa cho người Việt**, bắt đầu từ vốn từ/ngữ cảnh hiện có rồi dẫn người học đến nghe, nói, phản xạ, sửa lỗi và dùng tiếng Anh trong tình huống thật.

## North Star Metric

**Số phút nói tiếng Anh tự tin mỗi tuần trên mỗi người học đang hoạt động.**

Chỉ số phụ:

- Số lượt người học hoàn thành hội thoại 2-5 phút mà không bỏ cuộc.
- Tỷ lệ người học quay lại luyện nói trong 7 ngày.
- Số câu nói được AI/coach đánh giá là dễ hiểu hơn sau 4 tuần.
- Mức tự tin tự đánh giá trước/sau bài luyện nói.
- Tỷ lệ người học dùng lại từ/cụm từ đã học trong bài nói.

## Định Vị Sản Phẩm

Expat8 không nên cạnh tranh trực diện với app học ngoại ngữ đại trà. Lợi thế nên là:

- Thiết kế riêng cho người Việt học nói tiếng Anh.
- Giải thích bằng tiếng Việt khi cần, nhưng kéo người học dần sang phản xạ tiếng Anh.
- Tập trung vào phát âm, nghe hiểu, phản xạ và hội thoại thật.
- Cá nhân hóa theo trình độ, chủ đề, mục tiêu và lịch sử học.
- Offline-first cho học từ vựng và ôn tập, online-first cho AI speaking feedback.

## Nguyên Tắc Sản Phẩm

1. **Nói trước, ngữ pháp sau**: ưu tiên giúp người học dám nói, sửa lỗi theo mức vừa đủ.
2. **Ngữ cảnh thật thay vì danh sách từ rời rạc**: bài báo, tình huống công việc, phỏng vấn, du lịch, định cư, giao tiếp hàng ngày.
3. **Một vòng luyện tập ngắn nhưng đều**: mỗi ngày 5-10 phút phải tạo được cảm giác tiến bộ.
4. **Phản hồi phải hành động được**: không chỉ chấm điểm, phải chỉ ra câu sửa, cách nói tự nhiên hơn, bài tập kế tiếp.
5. **Tôn trọng sự ngại nói của người Việt**: bắt đầu bằng shadowing, đọc theo, trả lời ngắn, rồi mới hội thoại mở.
6. **Không biến app thành kho tính năng**: mọi tính năng phải phục vụ mục tiêu nói tự tin.

## Nền Tảng Hiện Có

Expat8 hiện đã có các nền móng quan trọng:

- Flutter mobile app với ObjectBox local storage và offline-first learning session.
- Backend Express + PostgreSQL quản lý vocabulary, study events, proficiency và sync.
- Adaptive CEFR proficiency ladder cho tiếng Anh.
- Article ingestion pipeline để biến nội dung thật thành vocabulary có ngữ cảnh.
- Admin dashboard để nhập bài, review vocabulary và publish content.
- App credential signing, session auth, readiness probe và Docker deployment.

Roadmap nên tận dụng những nền tảng này thay vì viết lại từ đầu.

## Chiến Lược 2 Năm

### Giai Đoạn 1: 0-3 Tháng - Củng Cố Nền Học Từ Thành Nền Nói

Mục tiêu: người học không chỉ xem flashcard mà bắt đầu **đọc to, nghe lại và nói câu ngắn** với nội dung đã học.

Sản phẩm:

- Thêm chế độ `Listen -> Repeat -> Compare` cho mỗi vocabulary card.
- Mỗi từ/cụm từ có 1-2 câu mẫu nói được trong đời sống thật.
- Người học có thể bấm ghi âm câu mẫu và nghe lại chính mình.
- Thêm bài mini-drill 3 phút: 5 từ đã học -> 5 câu nói ngắn.
- Thêm self-rating sau bài nói: `I said it clearly`, `I hesitated`, `I could not say it`.
- Dùng study events mới cho speaking actions, không chỉ memory rating.

Kỹ thuật:

- Mobile: audio recording/playback, local speaking attempt storage, offline queue.
- Backend: thêm speaking study events và schema lưu attempt metadata.
- Content: mở rộng `word_senses`/content model để có speaking prompt, natural phrase, common Vietnamese mistake.
- Dashboard: review được speaking prompts và common mistakes.

Deliverables:

- MVP speaking card.
- Speaking event sync.
- Dashboard review field cho câu mẫu nói.
- Báo cáo weekly: số phút luyện nói, số lần ghi âm, số câu hoàn thành.

Success metric:

- 30% người dùng active ghi âm ít nhất 3 lần trong tuần đầu.
- Người học hoàn thành tối thiểu 10 câu nói/tuần.

### Giai Đoạn 2: 3-6 Tháng - AI Pronunciation & Confidence Feedback

Mục tiêu: người học nhận được feedback phát âm/câu nói rõ ràng, không gây xấu hổ, có bài sửa cụ thể.

Sản phẩm:

- AI chấm độ dễ hiểu của câu nói theo 3 mức: `clear`, `understandable`, `needs practice`.
- Phản hồi bằng tiếng Việt ngắn gọn: lỗi âm chính, trọng âm, nối âm hoặc nhịp câu.
- So sánh câu người học nói với câu mẫu: thiếu từ, sai âm, ngập ngừng.
- Gợi ý 1 bài tập sửa lỗi duy nhất sau mỗi lần nói.
- Daily speaking streak: 3 phút/ngày.
- Private mode rõ ràng: bản ghi âm của người học không public, có thể xóa.

Kỹ thuật:

- Tích hợp speech-to-text hoặc pronunciation scoring qua provider có thể thay thế.
- Lưu transcript, score, feedback và audio retention policy.
- Queue xử lý async cho audio feedback để không block UI.
- Thêm endpoint upload audio attempt và poll/get result.
- Thiết kế privacy controls cho bản ghi âm.

Deliverables:

- `/v1/speaking/attempts` API.
- Worker xử lý audio feedback.
- Mobile speaking feedback screen.
- Dashboard/content QA cho prompt và rubric.

Success metric:

- 50% attempts nhận feedback trong dưới 20 giây.
- 40% người học quay lại sửa cùng một câu ít nhất 1 lần.
- Người học báo tăng tự tin sau 2 tuần >= 20% so với baseline survey.

### Giai Đoạn 3: 6-12 Tháng - Personalized Speaking Path

Mục tiêu: Expat8 biết người học cần nói gì, yếu ở đâu và nên luyện bài nào tiếp theo.

Sản phẩm:

- Onboarding mục tiêu nói: công việc, phỏng vấn, du lịch, định cư, giao tiếp hằng ngày, IELTS speaking.
- Speaking path theo CEFR: A1/A2 sống sót, B1 phản xạ, B2 tranh luận nhẹ, C1 trình bày ý kiến.
- Bài học theo tình huống: gọi món, họp team, giới thiệu bản thân, hỏi đường, phỏng vấn, small talk.
- Tự động tái sử dụng vocabulary đã học trong speaking prompts.
- Review lỗi cá nhân: âm hay sai, cụm từ hay bí, chủ đề hay ngập ngừng.
- Weekly confidence report bằng tiếng Việt.

Kỹ thuật:

- Learner model mới: speaking goals, weak sounds, hesitation patterns, active phrase bank.
- Recommendation service chọn prompt dựa trên vocabulary, proficiency, goals và past attempts.
- Content taxonomy: topic, scenario, communicative function, CEFR target, Vietnamese learner pain point.
- Analytics event pipeline cho speaking funnel.

Deliverables:

- Personalized speaking path.
- Scenario lesson format.
- Weekly report.
- Admin dashboard quản lý scenario/prompt taxonomy.

Success metric:

- 25% weekly active learners hoàn thành ít nhất 3 speaking sessions/tuần.
- 60% người học có ít nhất một lỗi cá nhân được hệ thống phát hiện và đề xuất bài sửa.
- Retention D30 tăng rõ rệt so với baseline vocabulary-only app.

### Giai Đoạn 4: 12-18 Tháng - Conversational AI Coach

Mục tiêu: người học luyện hội thoại 2-5 phút với AI coach an toàn, thực tế và phù hợp trình độ.

Sản phẩm:

- AI role-play theo tình huống: airport, interview, meeting, restaurant, doctor, networking.
- Coach điều chỉnh tốc độ, độ khó và lượng tiếng Việt theo trình độ.
- Conversation repair: khi người học bí, coach gợi ý 2-3 cách nói thay vì kết thúc cuộc hội thoại.
- Feedback cuối buổi: câu nói tốt nhất, lỗi cần sửa, 3 cụm từ nên dùng lại.
- Shadowing mode từ hội thoại mẫu.
- Export phrase bank cá nhân sau mỗi buổi.

Kỹ thuật:

- Realtime hoặc near-realtime conversation service.
- Guardrails cho AI coach: không nói quá khó, không sửa quá nhiều, không làm người học mất tự tin.
- Session memory ngắn hạn và phrase bank dài hạn.
- Cost controls: giới hạn thời lượng, model routing, caching prompts, batch feedback.
- Safety and privacy logs không chứa audio raw lâu hơn cần thiết.

Deliverables:

- 10-20 role-play scenarios chất lượng cao.
- AI speaking coach beta.
- Conversation summary và phrase bank.
- Cost dashboard cho audio/LLM usage.

Success metric:

- 20% active learners hoàn thành hội thoại >= 2 phút/tuần.
- 70% cuộc hội thoại kết thúc bằng feedback có ít nhất một next action cụ thể.
- Chi phí AI/session nằm trong ngưỡng business chấp nhận được.

### Giai Đoạn 5: 18-24 Tháng - Human Feedback, Community & Monetization

Mục tiêu: biến tiến bộ speaking thành niềm tin bền vững và mô hình kinh doanh có thể mở rộng.

Sản phẩm:

- Human coach review tùy chọn cho bài nói quan trọng: interview intro, presentation, IELTS cue card.
- Small group speaking challenge cho người Việt cùng trình độ.
- Community prompt: mỗi ngày một câu hỏi, trả lời bằng voice, có phản hồi AI trước khi public.
- Learning plan trả phí: 4 tuần tự tin phỏng vấn, 8 tuần nói công sở, 12 tuần giao tiếp du lịch.
- Certificate nội bộ dựa trên speaking streak, scenario completion và clarity improvement.

Kỹ thuật:

- Coach portal nhẹ cho human reviewers.
- Moderation và consent flow cho community voice.
- Subscription/entitlement service.
- B2B classroom/teacher dashboard nếu nhắm trung tâm tiếng Anh hoặc doanh nghiệp.

Deliverables:

- Paid speaking plans.
- Human feedback marketplace hoặc reviewer workflow nội bộ.
- Community speaking challenge beta.
- Basic subscription/paywall infrastructure.

Success metric:

- Paid conversion từ active speaking users đạt mức có thể kiểm chứng.
- Người học trả phí có weekly speaking minutes cao hơn nhóm free.
- 30% người học hoàn thành plan 4 tuần báo cáo tự tin hơn khi nói tiếng Anh.

## Product Bets Ưu Tiên

### Bet 1: Speaking Loop Ngắn Hằng Ngày

Nếu Expat8 giúp người học nói 3 phút/ngày đều đặn, sản phẩm sẽ có retention và tác động thực tế tốt hơn bất kỳ kho từ vựng nào.

### Bet 2: Vietnamese-Specific Feedback

Người Việt thường gặp các vấn đề như âm cuối, trọng âm, nối âm, thiếu phản xạ câu ngắn và dịch từng chữ từ tiếng Việt. Feedback riêng cho người Việt sẽ tạo khác biệt lớn.

### Bet 3: Context From Real Content

Article ingestion hiện có là lợi thế: từ nội dung thật -> từ/cụm từ -> câu nói -> hội thoại. Đây là đường đi tự nhiên từ đọc/nghe sang nói.

### Bet 4: Confidence, Not Perfection

Chấm điểm quá nghiêm sẽ làm người học sợ nói. Sản phẩm nên đo `clear enough to communicate` trước khi đòi native-like pronunciation.

## Roadmap Theo Năng Lực Kỹ Thuật

### Mobile

- Audio recording/playback ổn định trên Android/iOS.
- Speaking attempt local outbox để offline hoặc mạng yếu vẫn không mất dữ liệu.
- Speaking session UI không gây áp lực: record, retry, compare, feedback.
- Personalized path UI: hôm nay luyện gì, vì sao, mất bao lâu.

### Backend

- Speaking attempts API và async worker.
- Speech-to-text/pronunciation provider abstraction.
- Learner speaking profile và recommendation logic.
- Audio privacy, retention, deletion và audit trail.
- Cost monitoring cho LLM/audio jobs.

### Content & Dashboard

- Scenario/prompt management.
- Vietnamese learner mistake taxonomy.
- Review flow cho AI-generated speaking prompts.
- Publishing workflow theo CEFR, topic và goal.

### Data & Analytics

- Speaking minutes, attempts, retry rate, completion rate.
- Confidence survey before/after.
- Error trend theo âm/cụm từ/chủ đề.
- Funnel: install -> first card -> first recording -> first feedback -> first conversation -> paid plan.

## Những Điều Không Nên Làm Trong 12 Tháng Đầu

- Không mở quá nhiều ngôn ngữ mới khi mục tiêu chính là giúp người Việt nói tiếng Anh.
- Không xây social network rộng trước khi core speaking loop có retention.
- Không chạy theo gamification nặng nếu người học vẫn chưa nói nhiều hơn.
- Không để AI sửa mọi lỗi trong một lần; feedback quá nhiều làm người học nản.
- Không biến dashboard thành CMS phức tạp trước khi có content loop đủ dùng.
- Không tối ưu native-like accent quá sớm; ưu tiên intelligibility và confidence.

## Team & Process Đề Xuất

### 0-6 Tháng

- 1 mobile engineer tập trung speaking UI/audio.
- 1 backend engineer tập trung speaking APIs, worker và data model.
- 1 product/content lead hiểu người Việt học tiếng Anh.
- 1 part-time pronunciation/English coach để định nghĩa rubric và prompt quality.

### 6-12 Tháng

- Thêm data/analytics ownership.
- Thêm content operations cho scenario library.
- Thêm QA tập trung audio/device/network edge cases.

### 12-24 Tháng

- Thêm growth/monetization owner.
- Thêm human coach operations nếu mở reviewer workflow.
- Thêm infra/cost optimization nếu usage audio/LLM tăng mạnh.

## Milestone Tóm Tắt

| Mốc | Kết quả chính | Dấu hiệu thành công |
|---|---|---|
| 3 tháng | Vocabulary card có speaking drill | Người học ghi âm đều đặn |
| 6 tháng | AI pronunciation feedback | Người học sửa lại câu sau feedback |
| 12 tháng | Personalized speaking path | Người học luyện theo goal rõ ràng |
| 18 tháng | AI role-play coach | Người học hoàn thành hội thoại 2-5 phút |
| 24 tháng | Paid plans + human/community feedback | Có tín hiệu monetization và retention |

## Kết Luận

Hướng đi tốt nhất cho Expat8 trong 1-2 năm tới là giữ nền tảng vocabulary/offline-first hiện có, nhưng dùng nó như **đầu vào cho speaking confidence loop**:

```text
Nội dung thật -> Từ/cụm từ hữu ích -> Câu nói ngắn -> Ghi âm -> Feedback -> Sửa lại -> Hội thoại -> Tự tin hơn
```

Nếu sản phẩm đo và tối ưu đúng một điều, đó nên là: **người Việt có nói tiếng Anh nhiều hơn, rõ hơn và bớt sợ hơn sau mỗi tuần hay không**.
