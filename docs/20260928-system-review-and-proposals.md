# Expat8 — Review hiện trạng hệ thống & Đề xuất

> Ngày review: 2026-09-28 · Phạm vi: `backend/`, `mobile/`, `expat8-dashboard/`, `contracts/`, `docs/`, working tree chưa commit trên `main` (commit cuối: 2026-05-31).
> Tài liệu nền: [Roadmap 12 tháng](20260530-project-roadmap-12-month.md), [Product roadmap 2026-2028](20260509-expat8-product-roadmap-2026-2028.md), [Project overview](project-overview.md), [`contracts/api.md`](../contracts/api.md).

---

## 1. Tóm tắt điều hành

| Hạng mục | Đánh giá | Ghi chú ngắn |
|---|---|---|
| Mục đích sản phẩm | Rõ ràng | North Star: *số phút nói tiếng Anh tự tin mỗi tuần* của người Việt |
| Độ phủ chức năng | Rộng — vượt nhu cầu giai đoạn | 12+ bề mặt học tập; đã có đủ nguyên liệu cho vòng "từ vựng → nói" |
| Kiến trúc | Hợp lý cho quy mô hiện tại | Offline-first mobile + Express/PostgreSQL + worker LLM + dashboard Next.js |
| Chất lượng code | Trung bình, đang tích nợ | Store backend ~3.000 dòng/file, hai bản cài đặt song song; client mobile 2.250 dòng |
| Trạng thái build | **Đỏ** | Backend: 4/299 test fail do thay đổi chưa commit ở `user_identity.js`. Mobile: 18/244 test fail trên Flutter 3.47.5 local |
| Tiến độ roadmap | **Đình trệ ~4 tháng** | Phase 0–2 xong code từ 30/05; các gate cần thiết bị thật vẫn *Pending*; không có commit mới từ 31/05 |
| Vận hành & CI | Yếu | CI chỉ build APK; không chạy test backend/mobile/dashboard; migration không tự apply |

> **Cập nhật 2026-09-28 (sau khi sửa):**
> - Đã sửa: F1, F1b, F2, F3, F5, F6 và các lỗi phát hiện thêm khi chạy PostgreSQL thật (F14–F17 bên dưới).
> - Kết quả: backend 311/311 test (gồm PostgreSQL 16 thật, 0 skip), eslint sạch, 0 lỗ hổng; mobile 246/246 test, analyzer 0 error/warning, Flutter ghim 3.47.5; dashboard lint/test/build xanh, 0 lỗ hổng. (CI trên PR đã được gỡ ngày 2026-09-28 theo quyết định của chủ dự án vì thời gian chờ check quá lâu; kiểm tra chạy local theo `docs/testing-guide.md`.)
> - Còn lại cho production: chạy `npm run migrate` và đặt `TRUST_PROXY` trên Z440 ([deployment-guide](deployment-guide.md#database-migrations)); gate test trên thiết bị Android thật (F4); các mục P2 (F7–F13).

**Ba việc quan trọng nhất cần làm ngay:**

1. Sửa lỗi `crypto.promises.scrypt` (đăng ký/đăng nhập trên PostgreSQL sẽ lỗi 500 nếu deploy bản hiện tại) và hoàn tất change `fail-closed-replay-protection`.
2. Đóng các gate "device verification" của Phase 0–2 trong 1–2 tuần, đưa build tới nhóm người dùng thật và bắt đầu đo North Star.
3. Dựng CI test tối thiểu (backend + mobile + dashboard) để chặn lỗi như (1) trước khi merge.

---

## 2. Mục đích và định vị sản phẩm

**Tầm nhìn:** giúp người Việt *nói tiếng Anh tự tin trong đời sống thật*, chuyển dần từ app học từ vựng offline-first thành **AI speaking coach cá nhân hóa cho người Việt**.

**North Star:** số phút nói tiếng Anh tự tin mỗi tuần trên mỗi người học hoạt động.

**Vòng học cốt lõi (learner loop):**

```
Gặp/thêm từ ──► Ôn SRS ──► Luyện trong ngữ cảnh ──► Nói / shadowing ──► Tổng kết tuần ──► Gợi ý bài tiếp theo
 (cards,          (swipe,     (article, workplace      (speaking drill,     (/v1/speaking/      (chưa có —
  submitted        FITB,       sentence, memorization,   shadowing video)     summary)            Phase 3)
  words)           CEFR)       passage)
```

**Nguyên tắc sản phẩm đã cam kết:** nói trước ngữ pháp sau; ngữ cảnh thật; vòng ngắn 5–10 phút/ngày; phản hồi hành động được; tôn trọng sự ngại nói; *không biến app thành kho tính năng*.

**Nhận xét:** mục đích rõ và nhất quán giữa các tài liệu. Tuy nhiên độ rộng tính năng hiện tại (xem mục 3) đã đi trước khả năng đo lường — hệ thống chưa có dữ liệu người dùng thật để xác nhận vòng học có hiệu quả, và chưa có "một màn hình vòng học hôm nay" dẫn người học đi qua các bước.

---

## 3. Chức năng hiện có

| Nhóm | Chức năng | Mobile | Backend | Dashboard | Trạng thái |
|---|---|---|---|---|---|
| Từ vựng | Flashcard swipe + fill-in-the-blank, SRS, cache chống trùng phía server | ✔ | `/v1/learning/cards`, `/v1/user-word-cache` | — | Shipped |
| Trình độ | CEFR A1→C2 (EN), HSK1→6 (ZH); lên/xuống sau 5 lần `too_easy`/`hard` liên tiếp | ✔ | `/v1/proficiency` | `/system/srs` | Shipped |
| Đồng bộ | Study events đơn lẻ + batch, idempotent qua `client_event_id`, hàng đợi offline | ✔ | `/v1/study-events[/sync]` | `/analytics/study-events` | Shipped |
| Tài khoản | Ẩn danh theo `device_id`, đăng ký/đăng nhập, claim trạng thái thiết bị | ✔ | `/v1/users/*` | `/users` | Shipped |
| Từ do người học nhập | Queue local → worker LLM enrich → vào kho học | ✔ | `/v1/user-submitted-words` | — | Shipped |
| Bài báo | Ingest → trích từ → LLM enrich → review → publish | ✔ | `/v1/articles`, admin | `/articles`, `/review` | Shipped |
| Workplace sentence | Câu mẫu môi trường công việc | ✔ | `/v1/workplace-sentences` | `/content/workplace-sentences` | Shipped |
| Memorization passage | Chia đoạn, IPA, dịch, tiến độ theo đoạn | ✔ | memorization routes | `/memorization` | 71/75 task — gate E2E pending |
| Speaking | Ghi âm + nghe lại + tự đánh giá (không upload audio), `loop_completed` | ✔ | `/v1/speaking/*` | `/speaking-prompts`, `/analytics/speaking` | Shipped, device smoke pending |
| Shadowing video | Thư viện YouTube + transcript theo segment | ✔ | shadowing routes | — | 21/24 task — gate Android pending |
| Kiểm tra | Exam MCQ theo ngôn ngữ, chứng chỉ public | ✔ | `/v1/exam/*` | `/exam`, `/analytics/exam` | Shipped, device verify pending |
| Phát hành | Metadata release, banner tự nâng cấp trong app | ✔ | releases routes | — | Shipped |
| Vận hành | Upload log mobile, health/ready, loop health, content pipeline health | ✔ | admin routes | `/ops`, `/system/pipeline` | Shipped |

---

## 4. Kiến trúc hệ thống

### 4.1 Topology runtime

```
┌──────────────────────────┐        HMAC-signed HTTPS (x-expat8-*)        ┌──────────────────────────────┐
│ Flutter mobile (1.2.1+3) │ ───────────────────────────────────────────► │ Backend API  (Node 22,       │
│  ObjectBox: words, study │   + Bearer session (tuỳ chọn)                │ Express 5, ESM)  :8787       │
│  events, sync queue,     │ ◄─────────────────────────────────────────── │  middleware: CORS → req ctx  │
│  settings, logs          │                                              │  → header check → raw body   │
│  TTS / record / YouTube  │                                              │  → HMAC + nonce → JSON → routes│
└──────────────────────────┘                                              └──────────────┬───────────────┘
                                                                                         │ PostgresWordStore
┌──────────────────────────┐   signed backendFetch (write, admin token)   ┌──────────────▼───────────────┐
│ Dashboard (Next.js 15,   │ ───────────────────────────────────────────► │ PostgreSQL                    │
│ React 19)                │                                              │ 28 bảng: words, study_events, │
│  23 trang admin/analytics│ ─── đọc trực tiếp bằng `pg` (lib/db.ts) ───► │ users, articles, jobs, nonces,│
└──────────────────────────┘                                              │ memorization_*, shadowing_* … │
                                                                          └──────────────▲───────────────┘
                                                                                         │ poll jobs
                                                        ┌────────────────────────────────┴───────────────┐
                                                        │ Worker (src/worker.js): article, submitted-word,│
                                                        │ passage segmentation, passage enrichment        │──► LiteLLM (tuỳ chọn)
                                                        └─────────────────────────────────────────────────┘
```

### 4.2 Thành phần và quy mô code

| Thành phần | Công nghệ | Quy mô chính | Ghi chú |
|---|---|---|---|
| Backend API | Express 5, `node:test` | ~14.000 dòng `src/`; 14 router; 30 file test, 299 test | `WordStore` (in-memory, 2.954 dòng) và `PostgresWordStore` (3.446 dòng) cài đặt cùng một interface |
| Worker | Cùng codebase backend | 4 worker trong 1 process | Graceful shutdown 10s; LLM không nằm trên request path |
| CSDL | PostgreSQL | `schema.sql` + 27 migration | Compose init từ `schema.sql`; migration **không** tự apply |
| Mobile | Flutter, ObjectBox 4 | ~23.800 dòng `lib/`; 24 file test | `backend_api_client.dart` 2.253 dòng, `local_database.dart` 1.949 dòng |
| Dashboard | Next.js 15, TS | 23 trang | Vừa gọi API ký HMAC vừa đọc PostgreSQL trực tiếp |
| Hợp đồng | `contracts/api.md` | Canonical | Đã audit drift tháng 5/2026 |
| Triển khai | Docker Compose (Z440) | postgres, backend, article-worker, dashboard | CI: chỉ `android-release.yml` |

### 4.3 Luồng dữ liệu chính

- **Lấy thẻ học:** mobile → `POST /v1/learning/cards` (`card_mode: "new"`, không gửi danh sách loại trừ) → backend chọn từ theo trình độ + `user_word_states` (SRS due) + `user_cached_words` → mobile lưu ObjectBox, học offline.
- **Chấm thẻ:** ghi local trước → `POST /v1/study-events` hoặc batch `/sync` → backend cập nhật SRS + proficiency, trả level mới. Lỗi mạng → hàng đợi retry.
- **Nội dung:** admin/người học tạo article/passage/word → job `pending_processing` → worker gọi LLM → `pending_review` (admin) hoặc `processed` (user) → publish → xuất hiện trong kho học.
- **Nói:** hoàn toàn local (ghi âm, nghe lại, tự chấm) → chỉ đồng bộ sự kiện hành vi → `/v1/speaking/summary` tổng hợp theo tuần.

### 4.4 Mô hình bảo mật

- Mọi `/v1/*` (trừ OPTIONS, certificate public) cần HMAC app credential + nonce chống replay; secret nhúng trong app chỉ là *rào cản lạm dụng*, không phải định danh.
- Session token lưu dạng SHA-256 phía server; mật khẩu scrypt.
- Admin: thêm header `X-Expat8-Admin-Token`.
- Đang thay đổi (chưa commit): replay protection **fail-closed** cho mọi method khi nonce store lỗi; lỗi 5xx không còn trả `error.message`, thay bằng `request_id`; rate-limit đăng nhập/đăng ký theo identifier; hash mật khẩu bất đồng bộ.

**Điểm mạnh kiến trúc:** offline-first thực sự; backend là nguồn sự thật cho SRS/proficiency; LLM tách khỏi request path và có fallback; idempotency ở sync; hợp đồng API tập trung; roadmap có gate bằng chứng rõ ràng.

---

## 5. Phát hiện và rủi ro

Mức độ: **P0** = chặn release/lỗi production · **P1** = rủi ro cao trong 1–3 tháng · **P2** = nợ kỹ thuật/quy trình.

| # | Mức | Phát hiện | Bằng chứng | Tác động |
|---|---|---|---|---|
| F1 | **P0 — Đã sửa** | `user_identity.js` dùng `crypto.promises.scrypt` — API này **không tồn tại** trong Node (`typeof require('crypto').promises === 'undefined'` trên v22.23) | `npm test`: 293 pass / **4 fail** (`postgres store registers users…`, `…duplicate user insert races…`, `…non-duplicate user insert errors`, `password hash functions are async…`) | Deploy working tree hiện tại → đăng ký/đăng nhập trên PostgreSQL trả 500. Sửa: `util.promisify(crypto.scrypt)` |
| F1b | P1 — Đã sửa | Test mobile đỏ: `flutter test` 226 pass / **18 fail** trên Flutter 3.47.5; `flutter pub get` tự nâng 10 package SDK-pinned trong `pubspec.lock` (vd. `test_api`, `leak_tracker`) | Fail ở `learning_screen_test` (5), `logs_screen_test` (4), `upgrade_check_screen_test` (4), `fitb_card_test` (3), `exam_results_screen_test` (1), `local_database_test` (1) | Phiên bản Flutter không được ghim (không có `.fvmrc`/ràng buộc SDK chặt) → không tái lập được build/test; chưa phân biệt được lỗi do SDK mới hay regression thật |
| F2 | P1 — Đã sửa | Rate-limit đăng nhập đổi sang key theo `identifier` thay vì IP | `routes/auth.js` `buildAuthRateLimitKey` | (a) Kẻ tấn công có thể khoá tạm tài khoản người khác bằng cách spam identifier đó; (b) credential stuffing trên nhiều identifier từ một IP không còn bị giới hạn. Nên giới hạn đồng thời cả IP và identifier |
| F3 | P1 — Đã sửa | Fail-closed replay protection áp dụng cả GET | `app.js` `appCredentialGuard` | Đúng về bảo mật, nhưng khi DB chập chờn mọi đọc đều 503. Cần xác nhận mobile coi 503 là lỗi tạm thời (retry/backoff, fallback local) — chưa thấy xử lý riêng cho 503 trong `backend_api_client.dart` |
| F4 | P1 | Roadmap đình trệ: Phase 0–2 đóng gate code từ 30/05 nhưng các gate thiết bị thật vẫn Pending; không commit nào sau 31/05 | Roadmap 12 tháng, `git log` | North Star chưa được đo trên người dùng thật; Phase 3 bị chặn vô thời hạn |
| F5 | P1 — Đã gỡ CI (quyết định 2026-09-28) | Không có CI cho test | `.github/workflows/` chỉ có `android-release.yml` | Lỗi như F1 có thể vào `main`/production |
| F6 | P1 — Đã sửa | Migration không tự apply; `schema.sql` và 27 migration phải được giữ song song bằng tay | `project-overview.md`, `verify:migrations` cần DB sống | Lệch schema giữa môi trường; nonce table đã từng thiếu (lý do có gate Phase 0) |
| F7 | P2 | Store backend là "god object" với hai bản cài đặt song song | `word_store.js` 2.954 dòng, `postgres_word_store.js` 3.446 dòng; ví dụ F1 cho thấy hai bản đã tách hành vi (sync vs async) | Mỗi tính năng phải viết 2 lần; test chủ yếu chạy in-memory nên hành vi PostgreSQL ít được bao phủ |
| F8 | P2 | Dashboard đọc thẳng PostgreSQL (`lib/db.ts`, `lib/analytics.ts`) bên cạnh API | — | Coupling schema ngoài hợp đồng API; mọi đổi schema phải sửa dashboard. 4 trang `/analytics/*` đi ngược non-goal "không xây nền tảng analytics lớn" |
| F9 | P2 | File mobile quá lớn | `backend_api_client.dart` 2.253, `local_database.dart` 1.949, `learning_session_controller.dart` 984, `learning_screen.dart` 922 dòng | Khó test, dễ xung đột; 82 package có bản mới không tương thích ràng buộc |
| F10 | P2 | Truy vết OpenSpec bị mất | Root `openspec/` bị `.gitignore` và không còn trên đĩa; roadmap tham chiếu `openspec/changes/create-project-roadmap/`, `phase-0-…` | Không kiểm chứng được task/gate; mâu thuẫn với "OpenSpec-driven" trong README |
| F11 | P2 | Phạm vi sản phẩm rộng so với nguyên tắc | 12 nhóm chức năng; HSK/tiếng Trung đang tồn tại trong khi "mở rộng đa ngôn ngữ" là non-goal | Chi phí bảo trì + test thiết bị tăng; người học thiếu một lối đi chính |
| F12 | P2 | Tài liệu phân tán, lẫn file tạm | 55 file trong `docs/` gồm 14 `COMMIT_REPORT_*` và 1 file log mobile `.txt`; `architecture.md` 1.034 dòng song song `architecture-guide.md` 85 dòng | Khó tìm tài liệu đúng; file log trong repo là thói quen rủi ro dữ liệu |
| F13 | P2 | File công cụ AI được track trong git | 28 file `.wolf/`, `.serena/`, `.omo/`; `token-ledger.json` chiếm ~1.600 dòng diff | Nhiễu diff/PR, dễ lộ thông tin môi trường |

**Phát hiện thêm khi chạy test trên PostgreSQL thật (đã sửa):**

| # | Mức | Phát hiện | Cách sửa |
|---|---|---|---|
| F14 | **P0** | PostgreSQL từ chối mọi sự kiện `loop_completed` (CHECK constraint thiếu giá trị + `attempt_id NOT NULL`) → chỉ số North Star Phase 1 không được ghi ở production | Migration `20260928_speaking_loop_completed_event_type.sql` + test trên PostgreSQL |
| F15 | **P0** | DB mới từ `schema.sql` thiếu 8 bảng (speaking, content packs, exam) và cột `study_events.event_id`; 4 migration không idempotent, 1 migration có câu lệnh PostgreSQL không hợp lệ | Migration runner `schema_migrations` (`npm run migrate`, `MIGRATE_ON_START`), sửa 4 migration |
| F16 | P1 | Backend biến lỗi DB (mất kết nối, lệch schema) thành `rejected_events` vĩnh viễn; mobile bỏ qua `duplicates` nên sự kiện gửi lại sau khi mất response bị kẹt retry mãi | Chỉ lỗi dữ liệu thành rejected, lỗi hạ tầng → 5xx; mobile đánh dấu duplicates đã sync, rejected → failed |
| F17 | P1 | Worker: tick chồng nhau khi gọi LLM lâu hơn 1s; SIGTERM lúc rảnh chờ 10s rồi thoát lỗi | Chặn tick chồng, thoát sạch ngay khi rảnh |

---

## 6. Đề xuất

### 6.1 Ngay lập tức (tuần này)

1. **Sửa F1** — trong `backend/src/user_identity.js`:
   ```js
   import { promisify } from 'node:util';
   const scryptAsync = promisify(crypto.scrypt);
   async function derivePasswordHashAsync(password, salt) {
     return (await scryptAsync(password, salt, 32)).toString('base64url');
   }
   ```
   Chạy lại `npm test` phải về 0 fail trước khi commit.
2. **Làm xanh test mobile (F1b)** — ghim phiên bản Flutter (FVM `.fvmrc` + `environment.flutter` trong `pubspec.yaml`), chạy lại trên phiên bản đã ghim để tách lỗi do SDK và regression thật, sau đó sửa 18 test.
3. **Sửa F2** — dùng hai limiter: theo IP (chống stuffing) và theo `ip + identifier` (chống brute-force một tài khoản mà không cho phép khoá tài khoản từ xa).
4. **Chốt change `fail-closed-replay-protection`** — thêm test/kiểm tra mobile: 503 `REPLAY_PROTECTION_UNAVAILABLE` → retry có backoff, sync queue giữ nguyên, card loading fallback local. Cập nhật `contracts/api.md` (503 áp dụng mọi method, 5xx trả `request_id` thay vì `message`).
5. **Commit riêng rẽ** các thay đổi bảo mật (replay, error body, auth) thay vì lẫn với file `.wolf/`/`.serena/`.

### 6.2 Ngắn hạn (2–6 tuần) — "Đóng vòng, đo thật"

| Việc | Mục tiêu | Tiêu chí xong |
|---|---|---|
| Ngày kiểm thử thiết bị Android tập trung | Đóng toàn bộ gate Pending Phase 0–2 (exam, summary, swipe prefetch, shadowing, memorization E2E) | Checklist có ảnh/log; OpenSpec change được archive |
| Beta kín 20–50 người học | Có dữ liệu North Star đầu tiên | Dashboard ops hiển thị phút nói/tuần, loop completion, retry, sync failure |
| CI tối thiểu (đã bỏ 2026-09-28, kiểm tra chạy local — xem [testing-guide.md](testing-guide.md)) | Chặn regression | GitHub Actions: `npm test` (kèm service PostgreSQL để chạy `postgres_*` test + `verify:migrations`), `flutter test`, dashboard `lint`+`build` trên mọi PR |
| Migration runner | Loại bỏ lệch schema | Bảng `schema_migrations`; backend/deploy apply migration khi khởi động; `schema.sql` sinh ra từ migration hoặc chỉ dùng cho test |
| Khôi phục truy vết OpenSpec | Minh bạch gate | Bỏ `openspec/` khỏi `.gitignore` (hoặc chuyển change đã archive vào `docs/specs/`) |
| Dọn repo | Giảm nhiễu | `.gitignore` cho `.wolf/hooks`, `token-ledger.json`, `.serena/`, `.omo/`; chuyển `COMMIT_REPORT_*` vào `docs/archive/`; xoá file log `.txt` |

### 6.3 Trung hạn (1–3 tháng) — "Một lối đi, ít bề mặt hơn"

**Sản phẩm**

- **Màn hình "Hôm nay" (Daily Loop):** một điểm vào duy nhất xếp 4 bước — 10 thẻ SRS → 1 câu/đoạn ngữ cảnh chứa từ vừa học → 1 drill nói/shadowing 3–5 phút → tự đánh giá + `loop_completed`. Các màn hình hiện có trở thành "thư viện" phụ. Đây là thay đổi ít code nhất mà tác động trực tiếp tới North Star.
- **Kết nối từ → ngữ cảnh → nói:** khi chọn prompt nói/shadowing, ưu tiên nội dung chứa từ người học vừa ôn (dữ liệu đã có trong `memorization_segment_terms`, `article_terms`).
- **Quyết định phạm vi:** đặt tiếng Trung/HSK ở chế độ bảo trì (không phát triển thêm) theo đúng non-goal; đóng băng thêm trang `/analytics/*` cho tới khi có câu hỏi vận hành cụ thể.

**Kỹ thuật**

- **Tách store theo domain** (identity, vocabulary/SRS, content-pipeline, speaking, memorization, shadowing, exam, releases). Mỗi domain một interface nhỏ + **một bộ contract test chung chạy trên cả in-memory và PostgreSQL**. Làm dần: domain mới/được sửa thì tách, không big-bang.
- **Mobile:** tách `BackendApiClient` theo domain (dùng chung lớp signing/transport), tách `LocalDatabase` thành repository theo entity; nâng cấp dependency theo đợt nhỏ có test.
- **Dashboard:** chuyển các đọc PostgreSQL trực tiếp sang admin API (hoặc tối thiểu dùng role DB read-only + view SQL ổn định) để schema chỉ có một consumer.
- **Quan sát:** metric worker backlog/job failure/LLM latency & cost (tiền đề bắt buộc của Phase 3).

### 6.4 Dài hạn (3–9 tháng) — theo gate roadmap

- **Phase 3 (AI feedback nhẹ)** chỉ bắt đầu khi beta có ≥4 tuần dữ liệu loop. Ưu tiên: gợi ý bài tiếp theo từ lịch sử (rẻ, không cần audio) → viết lại câu tự nhiên hơn → sau cùng mới đến chấm phát âm bất đồng bộ (cần chính sách quyền riêng tư audio, xem [speaking-audio-privacy](20260509-speaking-audio-privacy.md)).
- **Mở rộng quy mô:** rate limiter và nonce cache hiện phù hợp một instance; khi chạy nhiều instance backend, chuyển rate limit sang PostgreSQL/Redis dùng chung.
- **Phân phối:** hoàn tất đường Play Store (staged rollout, rollback) theo [canonical-release-path](canonical-release-path.md) trước khi mở beta rộng.

---

## 7. Lộ trình đề xuất tóm tắt

| Thời gian | Trọng tâm | Kết quả đo được |
|---|---|---|
| Tuần 0–1 | F1–F3 (gồm test mobile), commit bảo mật sạch, CI tối thiểu | `npm test` xanh trên CI; không còn lỗi auth |
| Tuần 2–6 | Device verification, beta kín, migration runner, dọn repo | Gate Phase 0–2 Closed; số liệu phút nói/tuần đầu tiên |
| Tháng 2–3 | Màn hình Daily Loop, tách store/client theo domain dần dần | Tỷ lệ hoàn thành loop, retention 7 ngày |
| Tháng 4–9 | Phase 3 AI feedback có kiểm soát chi phí | Độ trễ phản hồi, tỷ lệ luyện lại sau phản hồi, chi phí/người học |

---

## 8. Phụ lục — Bằng chứng review

- Test backend (working tree 2026-09-28): `299 tests, 293 pass, 4 fail, 2 skipped` — toàn bộ lỗi xuất phát từ `Cannot read properties of undefined (reading 'scrypt')`.
- Test mobile (2026-09-28, Flutter 3.47.5): `+226 -18`; `pubspec.lock`/`analysis_options.yaml` bị tool tự sửa khi chạy và đã được khôi phục.
- Node runtime: v22.23.2; `crypto.promises` = `undefined`.
- Bảng CSDL (`schema.sql`): words, study_events, users, user_sessions, user_proficiency, user_word_states, generation_runs, scheduler_locks, user_cached_words, articles, article_processing_jobs, user_submitted_words, user_submitted_word_jobs, shadowing_videos, shadowing_video_segments, shadowing_video_entries, workplace_sentences, article_workplace_sentences, terms, word_senses, article_terms, vocabulary_review_items, release_versions, memorization_passages, memorization_segments, memorization_segment_progress, memorization_segment_terms, nonces.
- Thay đổi chưa commit: `app.js`, `app_credentials.js`, `routes/auth.js`, `user_identity.js`, `word_store.js`, `postgres_word_store.js` + test tương ứng; OpenSpec `backend/openspec/changes/fail-closed-replay-protection/`.
