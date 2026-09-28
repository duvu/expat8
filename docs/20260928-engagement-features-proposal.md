# Expat8 — Đề xuất tính năng tạo thói quen học (học hỏi từ các app nổi tiếng)

> Ngày: 2026-09-28 · Liên quan: [Review hệ thống](20260928-system-review-and-proposals.md), [Roadmap 12 tháng](20260530-project-roadmap-12-month.md), [Product roadmap 2026-2028](20260509-expat8-product-roadmap-2026-2028.md)

## 1. Mục tiêu: "gây nghiện" nhưng đúng chỗ

Người học chỉ tiến bộ khi luyện **đều mỗi ngày**. Vì vậy "gây nghiện" ở đây nghĩa là: **quay lại mỗi ngày để nói**, không phải mở app để lướt. Mọi cơ chế thưởng trong tài liệu này đều được tính trên hành vi tạo ra North Star (*số phút nói tiếng Anh tự tin mỗi tuần*), không tính trên số lần mở app.

Khung thiết kế là vòng thói quen (Hook model):

```
 Tín hiệu kích hoạt ──► Hành động nhỏ ──► Phần thưởng ──► Đầu tư của người học
 (nhắc đúng giờ,        (1 vòng 5–7 phút:    (thấy mình tiến bộ,   (chuỗi ngày, bản ghi âm,
  chuỗi ngày sắp mất)    ôn từ → nói)         bất ngờ, ghi nhận)    từ vựng riêng, mục tiêu)
        ▲                                                                   │
        └──────────── đầu tư càng nhiều, lý do quay lại càng mạnh ◄─────────┘
```

## 2. Học được gì từ các app nổi tiếng

| App | Cơ chế giữ chân chính | Bài học cho Expat8 | Expat8 đã có? |
|---|---|---|---|
| **Duolingo** | Chuỗi ngày (streak) + đóng băng chuỗi; XP, nhiệm vụ ngày, giải đấu tuần; thông báo nhắc theo giờ quen học; bài học rất ngắn | Chuỗi ngày là động lực quay lại mạnh nhất; bài phải đủ ngắn để "không có lý do bỏ" | Chưa có chuỗi ngày, XP hay thông báo |
| **Speak** | Học bằng cách nói ngay từ đầu; phần lớn thời gian là người học nói; hội thoại AI theo tình huống | Nói là hoạt động chính, từ vựng là phương tiện | Có drill nói local, chưa có hội thoại |
| **ELSA Speak** | Chấm phát âm tới từng âm, tô màu âm sai, chỉ cách sửa; điểm số tăng dần tạo cảm giác tiến bộ | Phản hồi cụ thể từng âm tạo động lực luyện lại; rất hợp người Việt (âm cuối, trọng âm) | Chỉ có tự đánh giá |
| **Praktika** | Gia sư AI dạng avatar, hội thoại nhập vai | Nhân vật cố định tạo gắn bó cảm xúc | Chưa có |
| **Cake** | Clip video ngắn từ nội dung thật, nghe và nhại theo | Nội dung thật, ngắn, giải trí → dễ quay lại | Có shadowing video |
| **Anki / Memrise** | SRS ôn đúng lúc sắp quên; Memrise dùng video người bản xứ | SRS giữ từ lâu; "hàng đợi ôn hôm nay" tạo việc cần làm mỗi ngày | Có SRS |
| **Babbel** | Hội thoại đời thực theo mục tiêu (du lịch, công việc) | Cá nhân hoá theo mục tiêu sống thật | Có workplace sentence, bài báo |
| **HelloTalk / Busuu** | Cộng đồng, người bản xứ sửa bài | Phản hồi từ người thật rất giá trị nhưng cần kiểm duyệt | Ngoài phạm vi (non-goal) |

**Kết luận:** Expat8 đã có đủ *nội dung* và *hoạt động* (SRS, drill nói, shadowing, bài báo, tổng kết tuần). Thứ còn thiếu là **lớp tạo thói quen**: lý do quay lại mỗi ngày, phần thưởng khi hoàn thành, và bằng chứng tiến bộ cho người học thấy.

## 3. Giải pháp: 8 tính năng, xếp theo tác động / công sức

| # | Tính năng | Học từ | Tác động | Công sức | Đợt |
|---|---|---|---|---|---|
| 1 | Màn hình **"Hôm nay"**: một vòng 5–7 phút | Duolingo, Speak | Rất cao | Thấp | 1 |
| 2 | **Chuỗi ngày nói** + phiếu giữ chuỗi | Duolingo | Rất cao | Thấp | 1 |
| 3 | **Nhắc học thông minh** (thông báo local) | Duolingo | Cao | Thấp | 1 |
| 4 | **Nghe lại giọng mình của ngày đầu**: so sánh trước/sau | Riêng Expat8 | Cao | Thấp | 1 |
| 5 | **Nhiệm vụ ngày + phần thưởng bất ngờ** | Duolingo | Trung bình–cao | Trung bình | 2 |
| 6 | **Hành trình theo mục tiêu** (đi làm, phỏng vấn, du lịch, định cư) | Babbel | Cao | Trung bình | 2 |
| 7 | **Chấm độ dễ hiểu và lỗi phát âm của người Việt** | ELSA | Rất cao | Cao | 3 |
| 8 | **Nhập vai hội thoại ngắn với AI** | Speak, Praktika | Rất cao | Cao | 3 |

### 3.1 Màn hình "Hôm nay"

- Là màn hình mặc định khi mở app, chỉ có **một nút chính** "Bắt đầu vòng hôm nay".
- Vòng gồm 4 bước, có vòng tròn tiến độ:
  1. Ôn 8–10 thẻ SRS.
  2. Đọc 1 câu ngữ cảnh chứa từ vừa ôn.
  3. Nói hoặc shadowing 3 câu.
  4. Tự đánh giá mức tự tin.
- Kết thúc vòng: gửi `loop_completed` (đã có), hiện màn hình ăn mừng và **số phút đã nói hôm nay**.
- Các màn hình hiện có (Articles, Memorization, Shadowing…) chuyển vào mục "Luyện thêm".
- Lý do: cắt bỏ việc phải chọn "hôm nay học gì". Phần lớn người bỏ app bỏ ngay ở bước chọn.

### 3.2 Chuỗi ngày nói (streak)

- Chuỗi chỉ tăng khi **hoàn thành 1 vòng có phần nói**. Mở app thôi thì không tăng.
- **Phiếu giữ chuỗi:** người học *nhận thưởng* phiếu này khi hoàn thành đủ 7 ngày, tối đa giữ 2 phiếu. Phiếu không bán bằng tiền.
- Mốc 3/7/30/100 ngày có hiệu ứng riêng và thẻ chia sẻ (tận dụng hạ tầng chứng chỉ đã có).
- Tính theo **ngày giờ địa phương**, chạy được khi offline (ObjectBox), đồng bộ lên server qua sự kiện đã có.
- Ranh giới đạo đức: không dùng câu chữ kiểu "Bạn sắp mất tất cả!", có nút tắt nhắc chuỗi.

### 3.3 Nhắc học thông minh

- Dùng thông báo **local** (`flutter_local_notifications`), không cần server và vẫn chạy khi offline.
- Giờ nhắc = giờ người học hay hoàn thành vòng nhất trong 14 ngày qua. Mặc định 20:00.
- Tối đa **1 lần/ngày**, và chỉ nhắc khi hôm đó chưa học.
- Nội dung tiếng Việt, cá nhân hoá, ví dụ: "Hôm nay còn 6 từ đang chờ ôn và 1 câu nói về *phỏng vấn*."
- Bị bỏ qua 3 ngày liền thì giãn tần suất, tránh gây phiền và bị tắt thông báo hẳn.

### 3.4 Nghe lại giọng mình của ngày đầu

- Sau 7, 30 và 90 ngày, app tự ghép **bản ghi ngày đầu** với **bản ghi hôm nay** của cùng một câu để người học nghe.
- Đây là phần thưởng cảm xúc mạnh nhất: người học *nghe thấy* mình tiến bộ.
- Chi phí thấp: audio đã được lưu local. Không upload, đúng chính sách quyền riêng tư hiện tại ([speaking-audio-privacy](20260509-speaking-audio-privacy.md)).

### 3.5 Nhiệm vụ ngày và phần thưởng bất ngờ

- Mỗi ngày có 3 nhiệm vụ nhỏ, ví dụ:
  - Nói 3 câu có từ vừa học.
  - Shadowing 1 clip.
  - Ôn hết thẻ đến hạn.
- Thưởng XP khi hoàn thành. XP được tính theo **thời gian nói**, không tính theo số lần bấm.
- **Phần thưởng biến thiên:** thỉnh thoảng mở khoá bất ngờ, ví dụ một câu idiom hay, một clip mới, hoặc gấp đôi XP buổi tối.
- Không làm giải đấu công khai ở giai đoạn này, vì mạng xã hội là non-goal của roadmap. Chỉ xem xét sau khi có dữ liệu giữ chân người dùng.

### 3.6 Hành trình theo mục tiêu

- Khi bắt đầu dùng app, hỏi 2 câu:
  - "Bạn học để làm gì?" (đi làm, phỏng vấn, du lịch, định cư/expat).
  - "Mỗi ngày bạn có mấy phút?"
- Mỗi mục tiêu là một chuỗi **chương** (ví dụ "Tuần đầu ở chỗ làm mới", "Làm thủ tục nhập cảnh"). Chương dùng các loại nội dung đã có: workplace sentence, bài báo, speaking prompt, shadowing.
- Hoàn thành chương thì mở chương tiếp. Cảm giác "đang đi trên một hành trình" giữ chân người học lâu hơn so với danh sách bài rời rạc.

### 3.7 Chấm độ dễ hiểu và lỗi phát âm của người Việt

- Giai đoạn A (rẻ, chạy trên máy):
  - Dùng nhận dạng giọng nói on-device (`speech_to_text`), so bản nhận dạng với câu mẫu để ra **điểm dễ hiểu**.
  - Đánh dấu những từ không nhận ra.
- Giai đoạn B (lợi thế riêng):
  - Luật phát hiện các lỗi đặc trưng của người Việt: thiếu âm cuối (/t/, /k/, /s/, /z/), âm *th*, *-ed*, *-s*, trọng âm.
  - Kèm mẹo sửa bằng tiếng Việt.
- Giai đoạn C (đúng Phase 3 của roadmap): chấm phát âm trên server, bất đồng bộ, có đo chi phí và độ trễ.
- Lý do đưa vào: ELSA cho thấy phản hồi cụ thể khiến người học **tự nguyện luyện lại nhiều lần**, tức là tăng trực tiếp số phút nói.

### 3.8 Nhập vai hội thoại ngắn với AI

- Kịch bản 2–3 phút có mục tiêu rõ, ví dụ: gọi món, trả lời phỏng vấn, hỏi đường, gọi điện cho chủ nhà.
- AI chỉ dùng từ trong vốn từ người học đã ôn, kèm gợi ý câu trả lời để giảm ngại nói.
- Đúng giới hạn roadmap: đây **không phải** gia sư AI mở hoàn toàn (non-goal). Kịch bản bị giới hạn, có đường thoát khi AI lỗi, và chỉ mở khi Phase 3 đạt gate về chi phí và độ trễ.
- Có thể thêm một nhân vật cố định (kiểu "Anh Tom – đồng nghiệp người Úc") để tạo gắn bó.

## 4. Nguyên tắc đạo đức (bắt buộc)

- Chỉ thưởng cho hành vi học thật: thời gian nói và vòng hoàn thành.
- Không bán phiếu giữ chuỗi. Không có loot box, không đếm ngược giả.
- Nhắc tối đa 1 lần/ngày, dễ tắt, giãn tần suất khi bị bỏ qua.
- Có chế độ "nghỉ phép": tạm dừng chuỗi khi ốm hoặc đi du lịch.
- Audio ở lại trên máy, trừ khi người học đồng ý cho phép chấm trên server.

## 5. Đo lường

| Tính năng | Chỉ số chính | Chỉ số phụ |
|---|---|---|
| Hôm nay | Tỷ lệ phiên có `loop_completed` | Thời gian tới lúc bắt đầu nói |
| Chuỗi ngày | Giữ chân D7/D30 | Phân bố độ dài chuỗi, tỷ lệ dùng phiếu |
| Nhắc học | Tỷ lệ mở app từ thông báo rồi hoàn thành vòng | Tỷ lệ tắt thông báo |
| Trước/sau | Tỷ lệ luyện tiếp sau khi nghe lại | Lượt chia sẻ |
| Chấm phát âm | Số lần luyện lại mỗi câu | Điểm dễ hiểu sau 4 tuần |
| Hội thoại AI | Tỷ lệ hoàn thành kịch bản | Chi phí và độ trễ mỗi lượt |

Mỗi tính năng ra mắt sau một cờ bật/tắt (feature flag) cho beta kín, so sánh với nhóm đối chứng trong 2–4 tuần.

## 6. Lộ trình triển khai

| Đợt | Thời gian | Nội dung | Điều kiện |
|---|---|---|---|
| 1 | 3–4 tuần | Hôm nay, Chuỗi ngày, Nhắc học, Trước/sau | Sau khi đóng gate thiết bị Phase 0–2 và có beta kín |
| 2 | 4–6 tuần | Nhiệm vụ ngày + XP, Hành trình theo mục tiêu | Đợt 1 tăng D7 so với nhóm đối chứng |
| 3 | 8–12 tuần | Chấm độ dễ hiểu (A → B), Nhập vai AI | Gate Phase 3: đo được chi phí/độ trễ; luồng học local không bị chặn khi AI lỗi |

### Ghi chú kỹ thuật

- **Mobile (ObjectBox):**
  - Thêm entity `DailyLoopProgress` (ngày địa phương, các bước đã xong, số phút nói).
  - Thêm entity `StreakState` (độ dài chuỗi, số phiếu, ngày cuối). Tính hoàn toàn local.
  - Package mới: `flutter_local_notifications`, `speech_to_text`.
- **Backend:**
  - Tái dùng `speaking_events` và `loop_completed` (đã sửa lỗi PostgreSQL trong commit `98a76bc`).
  - Thêm sự kiện `streak_extended`, `quest_completed` vào `SPEAKING_EVENT_TYPES` + migration CHECK. Viết theo đúng quy trình migration mới.
  - Thêm `GET /v1/progress/overview` (chuỗi, XP, phút nói theo tuần) để đồng bộ nhiều thiết bị.
- **Dashboard:** thêm các chỉ số ở mục 5 vào thẻ loop health đã có. Không làm trang analytics mới.
- **Hợp đồng API:** cập nhật `contracts/api.md` trước khi viết code, theo quy tắc của roadmap.
