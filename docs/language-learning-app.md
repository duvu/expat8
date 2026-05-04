# Tài liệu sản phẩm và kỹ thuật: Ứng dụng học ngoại ngữ bằng Flutter

## 1. Tổng quan

Ứng dụng giúp người dùng học từ vựng ngoại ngữ theo cơ chế vuốt xuống để nhận thẻ học tiếp theo. Mỗi thẻ hiển thị một từ hoặc cụm từ mới kèm giải nghĩa, cách đọc dành cho người Việt, phiên âm IPA và ví dụ sử dụng.

Ứng dụng được xây dựng bằng Flutter, hỗ trợ Android và iOS. Dữ liệu học cần hoạt động tốt khi mạng yếu hoặc mất kết nối. Mobile chỉ lưu 1000 từ gần nhất trên máy, đồng thời đồng bộ với backend. Backend có thể lưu số lượng từ không giới hạn và dùng AI qua LiteLLM để sinh nội dung từ vựng mới.

Giai đoạn đầu chưa cần đăng nhập hoặc xác thực. Tuy nhiên kiến trúc dữ liệu và API cần chuẩn bị sẵn để sau này có thể cá nhân hóa theo người dùng, trình độ, ngôn ngữ nguồn, ngôn ngữ đích và lịch sử học.

## 2. Mục tiêu

- Cung cấp trải nghiệm học từ nhanh, đơn giản: vuốt xuống là có thẻ học tiếp theo.
- Duy trì tỉ lệ học gồm 3 từ mới và 7 từ ôn tập trong mỗi chu kỳ 10 thẻ.
- Cho phép học ổn định khi backend lỗi, timeout hoặc thiết bị offline.
- Lưu tối đa 1000 từ gần nhất trên mobile để kiểm soát dung lượng.
- Đồng bộ lịch sử học và dữ liệu từ với backend.
- Dùng AI để sinh từ mới, giải nghĩa, cách đọc cho người Việt, IPA và ví dụ.
- Thiết kế sẵn đường nâng cấp cho đăng nhập và cá nhân hóa sau này.

## 3. Không thuộc phạm vi giai đoạn đầu

- Đăng nhập, đăng ký, OAuth, email hoặc xác thực người dùng.
- Thanh toán, gói premium hoặc giới hạn theo subscription.
- Social learning, bảng xếp hạng, lớp học hoặc chia sẻ tiến độ.
- Đánh giá phát âm bằng giọng nói.
- Tự động xác định trình độ người học bằng bài test đầu vào.
- Dashboard quản trị đầy đủ cho đội nội dung.

## 4. Đối tượng người dùng

Người dùng chính là người Việt đang học ngoại ngữ, trước mắt ưu tiên tiếng Anh. Người dùng có thể học trong các phiên ngắn, nhiều lần trong ngày, và không muốn cấu hình phức tạp trước khi bắt đầu.

Các giả định ban đầu:

- Người dùng có thể chưa biết IPA, nên cần phiên âm gần đúng theo cách đọc tiếng Việt.
- Người dùng cần ví dụ ngắn, dễ hiểu và có thể áp dụng trong giao tiếp.
- Người dùng có thể học khi mạng chập chờn.
- Thiết bị mobile có dung lượng giới hạn, không nên lưu vô hạn local.

## 5. Trải nghiệm học chính

### 5.1 Luồng sử dụng

1. Người dùng mở app.
2. App tải trạng thái học gần nhất từ local database.
3. Người dùng vuốt xuống.
4. App chọn thẻ tiếp theo theo tỉ lệ:
   - 3 thẻ là từ mới.
   - 7 thẻ là từ ôn tập.
5. Thẻ hiển thị:
   - Từ hoặc cụm từ.
   - Loại từ nếu có.
   - Nghĩa tiếng Việt.
   - Phiên âm gần đúng cho người Việt.
   - Phiên âm IPA.
   - Ví dụ sử dụng bằng ngoại ngữ.
   - Dịch ví dụ sang tiếng Việt.
6. Người dùng đánh dấu mức độ nhớ, ví dụ:
   - Chưa nhớ.
   - Khó.
   - Nhớ.
   - Quá dễ.
7. App lưu kết quả học vào local database.
8. App đồng bộ nền với server khi có mạng.

### 5.2 Hành vi vuốt xuống

Vuốt xuống là hành động chính để lấy thẻ tiếp theo. App cần phản hồi nhanh, ưu tiên lấy dữ liệu đã có trong local trước nếu cần để tránh cảm giác chờ.

Khi thẻ tiếp theo là từ mới:

- App gọi backend để lấy từ mới.
- Nếu backend trả lời thành công trong tối đa 5 giây, dùng dữ liệu từ backend.
- Nếu backend lỗi, timeout quá 5 giây hoặc thiết bị offline, app lấy từ mới từ local database.
- Nếu local cũng không còn từ mới phù hợp, app có thể chuyển sang thẻ ôn tập và hiển thị trạng thái nhẹ như "Đang dùng nội dung đã lưu".

Khi thẻ tiếp theo là từ ôn tập:

- App ưu tiên chọn từ trong local database dựa trên lịch ôn tập.
- Không cần gọi backend trên đường chính của thao tác vuốt.
- Kết quả ôn tập được sync sau.

## 6. Tỉ lệ học mới và ôn tập

Tỉ lệ mục tiêu là 3 từ mới và 7 từ ôn tập trong mỗi chu kỳ 10 thẻ.

Ví dụ một chu kỳ:

```text
new, review, review, new, review, review, review, new, review, review
```

Không bắt buộc thứ tự phải cố định. App có thể trộn vị trí để trải nghiệm tự nhiên hơn, miễn là trong dài hạn giữ gần tỉ lệ 30% từ mới và 70% ôn tập.

Quy tắc đề xuất:

- Duy trì một bộ đếm `new_count` và `review_count` trong phiên học hiện tại.
- Nếu `new_count / total_count` thấp hơn 0.3, ưu tiên lấy từ mới.
- Nếu không có từ mới khả dụng, fallback sang ôn tập.
- Nếu không có từ ôn tập đến hạn, fallback sang từ mới.
- Sau mỗi 10 thẻ có thể reset chu kỳ hoặc dùng rolling window 10 thẻ gần nhất.

## 7. Ôn tập và lịch nhắc lại

Giai đoạn đầu có thể dùng thuật toán đơn giản, dễ triển khai, chưa cần spaced repetition phức tạp.

### 7.1 Trạng thái học của một từ

Mỗi từ trong local nên có trạng thái học riêng:

- `new`: chưa học hoặc mới được nhận.
- `learning`: đang học, chưa ổn định.
- `review`: đã học và cần ôn theo lịch.
- `mastered`: người dùng nhớ tốt, tần suất xuất hiện thấp hơn.

### 7.2 Gợi ý khoảng ôn tập

Khi người dùng phản hồi:

- `Chưa nhớ`: ôn lại sau vài phút hoặc trong cùng phiên.
- `Khó`: ôn lại sau 1 ngày.
- `Nhớ`: ôn lại sau 3 ngày.
- `Quá dễ`: ôn lại sau 7 ngày hoặc lâu hơn.

Các khoảng này là cấu hình ban đầu, backend có thể điều chỉnh sau khi có dữ liệu thực tế.

## 8. Local-first và giới hạn 1000 từ

Mobile chỉ lưu tối đa 1000 từ gần nhất. Đây là giới hạn cứng cho dữ liệu từ vựng được lưu local, không tính log kỹ thuật ngắn hạn hoặc queue đồng bộ nếu cần.

### 8.1 Nguyên tắc lưu local

- Lưu từ đã hiển thị gần đây nhất cho người dùng.
- Lưu đủ metadata để học offline.
- Lưu lịch sử phản hồi học gần đây để đồng bộ lại khi có mạng.
- Không phụ thuộc backend cho luồng ôn tập cơ bản.

### 8.2 Chính sách xóa local

Khi số từ local vượt quá 1000:

1. Sắp xếp theo `last_seen_at` hoặc `updated_at`.
2. Giữ lại 1000 từ mới nhất.
3. Xóa các từ cũ hơn khỏi local database.
4. Không xóa dữ liệu trên server.

Nếu một từ cũ đang có sự kiện học chưa sync, app cần sync sự kiện trước hoặc giữ sự kiện trong `sync_queue` cho đến khi gửi thành công.

## 9. Đồng bộ dữ liệu

### 9.1 Mục tiêu sync

- Server lưu lịch sử học dài hạn.
- Mobile hoạt động được khi offline.
- Sau này có thể đăng nhập và khôi phục lịch sử học trên thiết bị mới.
- Không mất dữ liệu học khi backend tạm lỗi.

### 9.2 Chiến lược sync

Mobile ghi mọi hành động học vào local trước. Sau đó sync nền với server theo cơ chế queue.

```text
User action
    |
    v
Local DB write
    |
    v
Sync queue
    |
    v
Backend API
    |
    v
Server DB
```

Nếu sync thất bại:

- Giữ item trong queue.
- Retry theo backoff.
- Không chặn người dùng học tiếp.

### 9.3 Xung đột dữ liệu

Giai đoạn chưa đăng nhập chủ yếu có một thiết bị, nên xung đột thấp. Sau khi có tài khoản nhiều thiết bị, cần quy tắc rõ hơn.

Quy tắc ban đầu:

- Event học là append-only, không ghi đè.
- Trạng thái tổng hợp của từ có thể tính lại từ event mới nhất.
- Nếu có conflict timestamp, server ưu tiên event có `client_event_id` duy nhất và `occurred_at`.

## 10. Kiến trúc tổng thể

```text
+----------------------+
| Flutter App          |
| Android / iOS        |
+----------+-----------+
           |
           | HTTPS API
           v
+----------+-----------+
| Backend API          |
| Word feed / Sync     |
+----------+-----------+
           |
           +------------------+
           |                  |
           v                  v
+----------+-----------+  +---+----------------+
| Database             |  | LiteLLM            |
| Words / Events       |  | AI Generation      |
+----------------------+  +--------------------+
```

## 11. Mobile app architecture

Flutter app nên tách các lớp chính:

- UI layer: màn hình học, thẻ từ, gesture vuốt, trạng thái loading/error nhẹ.
- State layer: quản lý phiên học, tỉ lệ new/review, trạng thái thẻ hiện tại.
- Repository layer: quyết định lấy dữ liệu từ backend hay local.
- Local data layer: SQLite hoặc Isar/Hive cho từ vựng, lịch học và sync queue.
- API client: gọi backend với timeout 5 giây cho từ mới.

### 11.1 Local database đề xuất

SQLite là lựa chọn an toàn cho dữ liệu có quan hệ rõ ràng, query lịch ôn tập và giới hạn 1000 bản ghi. Có thể dùng Drift để có type-safe query trong Flutter.

Bảng local đề xuất:

- `local_words`
- `study_events`
- `sync_queue`
- `app_settings`

## 12. Backend architecture

Backend cung cấp API cho:

- Lấy từ mới.
- Sync event học từ mobile.
- Trả về các từ gần đây nếu cần bootstrap local.
- Sinh từ mới bằng AI qua LiteLLM.
- Lưu từ đã sinh vào database để tái sử dụng.

Backend nên tách các module:

- API layer.
- Word feed service.
- AI generation service.
- Study sync service.
- Persistence layer.

## 13. Sinh dữ liệu bằng AI qua LiteLLM

Backend dùng LiteLLM để gọi model AI sinh từ mới. Mỗi lần cần từ mới, backend có thể:

1. Kiểm tra database có từ phù hợp chưa dùng hay không.
2. Nếu có, trả về từ từ database.
3. Nếu chưa đủ, gọi AI qua LiteLLM để sinh thêm.
4. Validate và chuẩn hóa dữ liệu.
5. Lưu kết quả vào database.
6. Trả về từ mới cho mobile.

### 13.1 Yêu cầu nội dung AI

Mỗi từ cần có:

- `term`: từ hoặc cụm từ.
- `language`: ngôn ngữ của từ.
- `meaning_vi`: nghĩa tiếng Việt.
- `part_of_speech`: loại từ nếu có.
- `ipa`: phiên âm IPA.
- `vietnamese_pronunciation`: cách đọc gần đúng cho người Việt.
- `example`: câu ví dụ bằng ngoại ngữ.
- `example_vi`: bản dịch tiếng Việt của ví dụ.
- `difficulty`: trình độ ước lượng, ví dụ A1, A2, B1, B2, C1.
- `topics`: chủ đề, ví dụ travel, work, daily life.

### 13.2 Prompt định hướng

Prompt backend nên yêu cầu AI trả về JSON có schema cố định, không trả văn bản tự do.

Ví dụ yêu cầu:

```text
Generate vocabulary items for Vietnamese learners.
Return valid JSON only.
Each item must include term, meaning_vi, part_of_speech, ipa,
vietnamese_pronunciation, example, example_vi, difficulty, topics.
The Vietnamese pronunciation should be a practical approximation for Vietnamese speakers,
not a replacement for IPA.
Avoid duplicate terms.
Use short, natural examples.
```

### 13.3 Kiểm tra chất lượng

Backend cần validate:

- JSON parse được.
- Đủ field bắt buộc.
- Không trùng từ đã có trong database theo `language + normalized_term`.
- IPA không rỗng.
- Ví dụ có chứa hoặc liên quan trực tiếp đến từ.
- Nội dung không độc hại hoặc không phù hợp.

Nếu AI trả dữ liệu lỗi, backend retry với prompt sửa lỗi hoặc bỏ item không hợp lệ.

## 14. API đề xuất

### 14.1 Lấy từ mới

```http
GET /v1/words/next?mode=new&limit=1&source_language=vi&target_language=en
```

Timeout phía mobile: 5 giây.

Response:

```json
{
  "items": [
    {
      "server_word_id": "word_123",
      "term": "reliable",
      "language": "en",
      "meaning_vi": "đáng tin cậy",
      "part_of_speech": "adjective",
      "ipa": "/rɪˈlaɪəbl/",
      "vietnamese_pronunciation": "ri-lai-ờ-bồ",
      "example": "She is a reliable teammate.",
      "example_vi": "Cô ấy là một đồng đội đáng tin cậy.",
      "difficulty": "B1",
      "topics": ["work", "people"],
      "created_at": "2026-05-04T00:00:00Z"
    }
  ]
}
```

### 14.2 Sync sự kiện học

```http
POST /v1/study-events/sync
```

Request:

```json
{
  "device_id": "device_abc",
  "events": [
    {
      "client_event_id": "evt_001",
      "server_word_id": "word_123",
      "local_word_id": "local_456",
      "rating": "remembered",
      "occurred_at": "2026-05-04T10:30:00Z"
    }
  ]
}
```

Response:

```json
{
  "accepted_event_ids": ["evt_001"],
  "rejected_events": []
}
```

### 14.3 Bootstrap local cache

```http
GET /v1/words/recent?limit=1000&source_language=vi&target_language=en
```

API này hữu ích khi app cài mới, đổi thiết bị hoặc sau này người dùng đăng nhập.

## 15. Data model đề xuất

### 15.1 Server database

#### `words`

| Field | Ý nghĩa |
| --- | --- |
| `id` | ID duy nhất trên server |
| `term` | Từ hoặc cụm từ |
| `normalized_term` | Dạng chuẩn hóa để chống trùng |
| `language` | Ngôn ngữ của từ |
| `meaning_vi` | Nghĩa tiếng Việt |
| `part_of_speech` | Loại từ |
| `ipa` | Phiên âm IPA |
| `vietnamese_pronunciation` | Cách đọc gần đúng cho người Việt |
| `example` | Câu ví dụ |
| `example_vi` | Dịch nghĩa câu ví dụ |
| `difficulty` | Trình độ ước lượng |
| `topics` | Danh sách chủ đề |
| `generation_source` | Model hoặc pipeline đã sinh từ |
| `created_at` | Thời điểm tạo |
| `updated_at` | Thời điểm cập nhật |

#### `study_events`

| Field | Ý nghĩa |
| --- | --- |
| `id` | ID server |
| `client_event_id` | ID từ mobile để chống gửi trùng |
| `device_id` | ID thiết bị khi chưa có user |
| `user_id` | Dự phòng cho giai đoạn có đăng nhập |
| `word_id` | ID từ trên server |
| `rating` | Mức độ nhớ |
| `occurred_at` | Thời điểm xảy ra trên client |
| `received_at` | Thời điểm server nhận |

#### `user_word_states`

Bảng này chưa bắt buộc ở giai đoạn đầu, nhưng nên thiết kế sẵn để cá nhân hóa sau này.

| Field | Ý nghĩa |
| --- | --- |
| `user_id` | User sau khi có auth |
| `device_id` | Dùng tạm trước khi có auth |
| `word_id` | ID từ |
| `status` | new, learning, review, mastered |
| `last_seen_at` | Lần học gần nhất |
| `next_review_at` | Lần ôn tiếp theo |
| `ease_factor` | Hệ số dễ nhớ nếu dùng SRS |
| `review_count` | Số lần ôn |

### 15.2 Local database

#### `local_words`

| Field | Ý nghĩa |
| --- | --- |
| `local_id` | ID local |
| `server_word_id` | ID server nếu đã có |
| `term` | Từ hoặc cụm từ |
| `language` | Ngôn ngữ của từ |
| `meaning_vi` | Nghĩa tiếng Việt |
| `part_of_speech` | Loại từ |
| `ipa` | Phiên âm IPA |
| `vietnamese_pronunciation` | Cách đọc gần đúng |
| `example` | Câu ví dụ |
| `example_vi` | Dịch câu ví dụ |
| `difficulty` | Trình độ |
| `topics` | Chủ đề |
| `status` | Trạng thái học local |
| `last_seen_at` | Lần hiển thị gần nhất |
| `next_review_at` | Lần cần ôn tiếp |
| `created_at` | Tạo local |
| `updated_at` | Cập nhật local |

#### `study_events`

| Field | Ý nghĩa |
| --- | --- |
| `client_event_id` | ID duy nhất local |
| `local_word_id` | ID từ local |
| `server_word_id` | ID từ server nếu có |
| `rating` | Mức độ nhớ |
| `occurred_at` | Thời điểm học |
| `sync_status` | pending, synced, failed |

#### `sync_queue`

| Field | Ý nghĩa |
| --- | --- |
| `id` | ID queue |
| `type` | Loại sync, ví dụ study_event |
| `payload` | JSON payload |
| `retry_count` | Số lần retry |
| `next_retry_at` | Thời điểm retry |
| `created_at` | Thời điểm tạo |

## 16. Fallback khi backend lỗi hoặc timeout

Luồng lấy từ mới cần tuân thủ timeout 5 giây:

```text
Need new word
    |
    v
Call backend with 5s timeout
    |
    +-- success --> save/update local --> show word
    |
    +-- failure/timeout/offline
            |
            v
       query local new words
            |
            +-- found --> show local word
            |
            +-- not found --> show due review word
```

Yêu cầu quan trọng:

- Timeout được xử lý ở mobile API client.
- Không để UI treo quá 5 giây.
- Không làm mất thao tác học khi backend lỗi.
- Có log hoặc analytics nội bộ để biết tần suất fallback.

## 17. Chuẩn bị cho auth tương lai

Dù chưa có đăng nhập, hệ thống nên có `device_id` ổn định để gom dữ liệu học.

Khi thêm auth sau này:

- Tạo `user_id`.
- Liên kết dữ liệu cũ theo `device_id` vào `user_id` sau khi người dùng đăng nhập.
- API hiện tại có thể giữ nguyên phần lớn, chỉ thêm authorization header.
- `study_events` tiếp tục append-only.
- `user_word_states` có thể merge từ nhiều thiết bị.

Nguyên tắc thiết kế:

- Không hard-code giả định "một thiết bị là một người dùng" vào database server.
- Luôn để `user_id` nullable trong giai đoạn đầu.
- `device_id` là định danh tạm, không phải bảo mật.

## 18. Yêu cầu phi chức năng

### 18.1 Hiệu năng

- Vuốt sang thẻ tiếp theo nên phản hồi gần như tức thì với thẻ ôn tập local.
- Gọi backend lấy từ mới timeout tối đa 5 giây.
- Local query chọn thẻ tiếp theo nên dưới 100 ms trên thiết bị phổ thông.
- Giới hạn 1000 từ local để database nhỏ và dễ bảo trì.

### 18.2 Độ tin cậy

- App vẫn học được khi offline.
- Sync retry không làm trùng event trên server.
- Backend AI failure không làm hỏng response API.
- Dữ liệu AI phải qua validate trước khi lưu.

### 18.3 Bảo mật và riêng tư

- Giai đoạn đầu chưa có dữ liệu định danh người dùng.
- `device_id` không nên chứa thông tin cá nhân.
- Khi có auth, token phải lưu bằng secure storage của iOS/Android.
- Log không nên chứa nội dung nhạy cảm hoặc thông tin cá nhân.

## 19. Telemetry đề xuất

Các event nên đo:

- `card_shown`
- `new_word_requested`
- `new_word_backend_success`
- `new_word_backend_timeout`
- `new_word_local_fallback`
- `review_word_shown`
- `study_rating_submitted`
- `sync_success`
- `sync_failed`
- `local_cache_pruned`

Các chỉ số quan trọng:

- Tỉ lệ backend timeout.
- Tỉ lệ fallback local.
- Số thẻ học trung bình mỗi phiên.
- Tỉ lệ từ mới và ôn tập thực tế.
- Tỉ lệ sync thành công.
- Số từ local trung bình trên thiết bị.

## 20. MVP đề xuất

### 20.1 Mobile

- Màn hình học chính với thao tác vuốt xuống.
- Thẻ từ hiển thị đầy đủ thông tin cơ bản.
- Local database lưu từ, trạng thái học và event.
- Bộ chọn thẻ theo tỉ lệ 3 mới, 7 ôn tập.
- API client timeout 5 giây.
- Fallback từ backend sang local.
- Sync queue nền.
- Giới hạn local 1000 từ.

### 20.2 Backend

- API lấy từ mới.
- API sync study events.
- Database lưu words và study events.
- Tích hợp LiteLLM để sinh từ mới.
- Validate JSON response từ AI.
- Deduplicate từ đã sinh.

### 20.3 Nội dung

- Ưu tiên tiếng Anh cho người Việt.
- Mỗi từ có nghĩa tiếng Việt, IPA, cách đọc gần đúng, ví dụ và bản dịch.
- Trình độ mặc định có thể là A1 đến B2.

## 21. Rủi ro và hướng xử lý

| Rủi ro | Tác động | Hướng xử lý |
| --- | --- | --- |
| AI sinh dữ liệu sai hoặc không tự nhiên | Người học mất niềm tin | Validate schema, deduplicate, sampling thủ công ban đầu |
| Phiên âm gần đúng gây hiểu sai | Người học phát âm lệch | Luôn hiển thị IPA cùng phiên âm gần đúng, ghi rõ đây là hỗ trợ đọc |
| Backend chậm | Trải nghiệm vuốt bị gián đoạn | Timeout 5 giây, fallback local, prefetch từ mới |
| Local chỉ có 1000 từ | Có thể thiếu từ mới khi offline lâu | Ưu tiên giữ từ gần nhất, cho phép ôn tập khi hết từ mới |
| Chưa có auth | Khó cá nhân hóa nhiều thiết bị | Dùng `device_id`, thiết kế `user_id` nullable |
| Sync trùng event | Sai thống kê học | Dùng `client_event_id` idempotent |

## 22. Câu hỏi còn mở

- Ngôn ngữ đích MVP chắc chắn là tiếng Anh hay cần hỗ trợ nhiều ngoại ngữ ngay từ đầu?
- Người dùng có cần chọn trình độ ban đầu thủ công không?
- Có cần audio phát âm trong MVP không, hay chỉ IPA và phiên âm gần đúng?
- Có cần moderation nội dung AI trước khi trả về người dùng không?
- Backend sẽ pre-generate từ theo batch hay generate theo demand?
- Local fallback cho từ mới nên lấy từ "chưa học" hay cho phép tái dùng từ đã từng học nhưng chưa nhớ?

## 23. Quyết định kỹ thuật đề xuất

- Flutter cho Android và iOS.
- Local database dùng SQLite với Drift nếu đội muốn type-safe query.
- Backend dùng REST API trước, GraphQL chưa cần thiết.
- AI generation đi qua LiteLLM để dễ thay model.
- Study event dùng append-only và idempotent sync.
- Mobile giữ 1000 từ gần nhất, server giữ không giới hạn.
- Giai đoạn đầu dùng `device_id`, chuẩn bị sẵn `user_id` nullable cho auth sau này.

## 24. Định nghĩa hoàn thành cho MVP

MVP được coi là hoàn thành khi:

- Người dùng có thể mở app và học bằng thao tác vuốt xuống.
- App duy trì gần đúng tỉ lệ 3 từ mới, 7 từ ôn tập.
- Mỗi từ hiển thị nghĩa, IPA, cách đọc cho người Việt và ví dụ.
- Khi backend lỗi hoặc timeout 5 giây, app lấy từ local.
- Mobile không lưu quá 1000 từ.
- Study events được lưu local và sync lên server.
- Backend sinh được từ mới qua LiteLLM, validate và lưu vào database.
- Kiến trúc dữ liệu không chặn việc thêm auth trong tương lai.
