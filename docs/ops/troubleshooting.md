# Xử lý sự cố

Tra theo triệu chứng. Mỗi mục gồm **kiểm tra** (chạy theo thứ tự) và **cách sửa**. Trước khi bắt đầu, chạy `node scripts/ops-check.mjs` để biết phạm vi lỗi. Xong việc thì ghi vào nhật ký vận hành: thời gian, triệu chứng, nguyên nhân, cách sửa.

Các lệnh `docker compose` chạy trong `~/deployment/worker-z440` trên Z440.

## Mức độ

| Mức | Ví dụ | Phản hồi |
|---|---|---|
| P1 | API chết hoàn toàn, DB mất, lộ secret, dữ liệu hỏng | Xử lý ngay |
| P2 | Đăng nhập/đồng bộ lỗi với nhiều người, worker chết, bản app mới lỗi | Trong ngày |
| P3 | Một bài viết/passage lỗi, một người dùng gặp lỗi lẻ | Trong tuần |

App offline-first: khi API chết, người học vẫn học được và dữ liệu nằm trong hàng đợi trên máy. P1 về API là "chậm đồng bộ", **không** phải mất dữ liệu, trừ mục 9.

---

## 1. App báo không kết nối được / `/health` lỗi

Kiểm tra:
```bash
curl -sS -m 5 https://expat8.x51.vn/health          # từ ngoài
curl -sS -m 5 http://<Z440_HOST>:18787/health       # trong mạng nội bộ
docker compose ps expat8-backend
docker logs --tail 50 expat8-backend
```
- Nội bộ OK nhưng public lỗi: reverse proxy hoặc DNS hỏng (máy chạy proxy cho `expat8.x51.vn`, không phải Caddy trên Z440).
- Container `Restarting`/`Exited`: xem log lúc khởi động. Hay gặp nhất là thiếu hoặc sai biến môi trường (`APP_CREDENTIALS_JSON` không phải JSON hợp lệ, `DATABASE_URL` sai).
- Container `unhealthy`: tiến trình treo, xem log rồi `docker compose restart expat8-backend`.

Sửa xong: `node scripts/ops-check.mjs`.

## 2. Request có ký bị từ chối (400 `bad_request`)

Backend trả **400** (không phải 401) cho mọi lỗi xác thực app: thiếu header, chữ ký sai, credential không `active`, nonce dùng lại, hoặc giờ lệch. Hậu quả nghiêm trọng: app coi 400 là lỗi vĩnh viễn nên **bỏ luôn** sự kiện trong hàng đợi đồng bộ (xem [Rủi ro đã biết](README.md#rủi-ro-đã-biết-cần-sửa-code)). Vì vậy lỗi loại này phải xử lý như P1 nếu xảy ra với nhiều người.

- **Sai credential:** app được build với `APP_CREDENTIAL_APP_ID/SECRET` không có (hoặc không `active`) trong `APP_CREDENTIALS_JSON`. So sánh secret GitHub Actions với `.env` ([secrets.md](secrets.md)). Thường xảy ra sau khi xoay vòng credential sai thứ tự.
- **Lệch giờ:** `x-expat8-timestamp` lệch quá `APP_CREDENTIAL_TIMESTAMP_SKEW_SECONDS` (300 giây) so với server.
  - Chỉ một người bị: giờ điện thoại sai, bảo họ bật giờ tự động **trước khi** mở app có mạng.
  - Mọi người bị: giờ server sai, kiểm tra `timedatectl` trên Z440 (NTP phải `active`).
- **Request lạ không có header:** bot hoặc client cũ, không cần xử lý.

Phân biệt với 400 do dữ liệu sai: log `request_completed` có `status_code: 400` trên **mọi** path của một thiết bị thì là lỗi xác thực; 400 chỉ ở một path thì là lỗi dữ liệu.

## 3. Đăng nhập báo "quá nhiều lần thử" (429) với nhiều người

`TRUST_PROXY` chưa đặt, nên mọi người dùng chung IP của reverse proxy và giới hạn 60 lần/phút (`AUTH_RATE_LIMIT_IP`) trở thành giới hạn toàn hệ thống. Đặt `TRUST_PROXY` theo [deploy.md](deploy.md#cấu-hình-bắt-buộc) rồi recreate `expat8-backend`.

Bị tấn công dò mật khẩu thật (nhiều IP khác nhau, cùng identifier): giới hạn theo IP + tài khoản vẫn giữ tài khoản an toàn. Nếu tải quá cao, chặn ở reverse proxy.

Bộ đếm rate limit nằm trong bộ nhớ, restart backend là xoá hết.

## 4. `/health/ready` 503 / API trả 503

`/health/ready` kiểm tra DB. API trả `503 REPLAY_PROTECTION_UNAVAILABLE` khi không ghi được nonce vào DB.

```bash
docker compose ps pgbouncer postgres
docker logs --tail 50 pgbouncer
docker compose exec -T postgres pg_isready
docker compose exec -T postgres psql -U <user> -c "select count(*) from pg_stat_activity"
```
- `postgres` chết: xem log Postgres (`/home/beou/datadir/logs`) và dung lượng đĩa (`df -h`). **Postgres dùng chung**, báo các dự án khác trước khi restart.
- Hết kết nối (gần `max_connections` = 100): tìm dự án chiếm nhiều kết nối nhất (`select datname, usename, count(*) from pg_stat_activity group by 1,2 order by 3 desc`).
- pgbouncer lỗi: `docker compose restart pgbouncer` làm rớt kết nối của mọi dự án dùng chung, nên báo trước.

Khi DB trở lại, backend tự kết nối lại, không cần restart.

## 5. Bài viết / passage kẹt hoặc lỗi xử lý

Người dùng thấy "Finding words…" hay "Preparing…" mãi, hoặc "Could not process".

```bash
docker compose ps expat8-worker
docker logs --since 1h expat8-worker 2>&1 | jq -Rc 'fromjson? | select(.level=="error" or .level=="warn")'
node scripts/admin-request.mjs GET /v1/admin/content-pipeline/health
```
- Worker không chạy: `docker compose up -d expat8-worker`.
- Log toàn lỗi `litellm_*`: LiteLLM chết hoặc hết quota/key sai (mục 6).
- Sửa xong nguyên nhân, cho các mục lỗi chạy lại:
  ```bash
  # bài viết lỗi (status processing_failed)
  docker compose exec -T postgres psql -U <user> -d <expat8_db> -Atc \
    "select id, title from articles where status = 'processing_failed' order by updated_at desc limit 50"
  node scripts/admin-request.mjs POST /v1/admin/articles/<article_id>/reprocess

  # passage lỗi tách đoạn (status failed) / lỗi làm giàu (enrichment_status failed)
  node scripts/admin-request.mjs GET '/v1/admin/memorization/passages?status=failed'
  node scripts/admin-request.mjs POST /v1/admin/memorization/passages/<id>/retry
  node scripts/admin-request.mjs PATCH /v1/admin/memorization/passages/<id>/retry-enrichment
  ```
  Dashboard cũng có nút tương ứng ở `/articles` và `/memorization/passages`.

## 6. LiteLLM lỗi

Ảnh hưởng: bài viết, passage, từ người dùng gửi và scheduler sinh từ vựng dừng lại. **Học thẻ, game, luyện nói, bài thi vẫn chạy**, vì LLM không nằm trên đường học.

- Kiểm tra: `curl -sS -m 10 $LITELLM_BASE_URL/health -H "Authorization: Bearer $LITELLM_API_KEY"` (tuỳ bản LiteLLM) và log `litellm_chat_completion_http_error` (xem mã HTTP: 401 là sai key, 429 là hết quota).
- Đổi key/model: sửa `LITELLM_*` trong `.env`, recreate `expat8-backend expat8-worker`.
- Khi LLM trở lại, retry các mục lỗi theo mục 5.

## 7. Migrate lỗi hoặc treo

**Lỗi (`db.migration.failed`):** migration lỗi đã tự rollback, các migration trước nó vẫn giữ. Đừng recreate backend bằng image mới. Đọc thông báo lỗi, sửa migration qua PR (migration phải idempotent), build image mới, chạy lại. Image cũ vẫn chạy bình thường trong lúc đó.

**Treo, không in gì:** thường do chạy qua pgbouncer hoặc có tiến trình khác đang giữ khoá migrate.
```bash
docker compose exec -T postgres psql -U <user> -d <expat8_db> -c \
  "select l.pid, a.application_name, a.state, a.query_start from pg_locks l join pg_stat_activity a using (pid) where l.locktype = 'advisory'"
# khoá bị bỏ rơi (tiến trình migrate đã chết): kết thúc session giữ khoá
docker compose exec -T postgres psql -U <user> -d <expat8_db> -c "select pg_terminate_backend(<pid>)"
```
Chạy lại migrate với URL **thẳng vào Postgres** theo [deploy.md](deploy.md#3-migrate-database).

## 8. Người dùng không đồng bộ được

1. Nhờ người dùng gửi log (Menu → Tools & settings → Logs → **Send logs to server**), rồi xem ở dashboard `/ops/logs`. Tìm các dòng category `sync`.
2. Đọc mã lỗi:
   - Lỗi mạng, 401, 429, 5xx: sự kiện **vẫn trong hàng đợi** và tự thử lại (lúc mở app, 3 phút một lần, khi có mạng lại, sau khi đăng nhập). Sửa phía server là xong.
   - 400/404/409/410/413/422: server từ chối hẳn, app **bỏ** sự kiện đó (không thử lại). Nếu nhiều người cùng bị, đó là lỗi backend hoặc lệch phiên bản (mục 9).
3. Phiên đăng nhập hết hiệu lực (401 cho request có bearer): người dùng đăng xuất rồi đăng nhập lại. Dữ liệu chưa đồng bộ vẫn giữ nguyên và được gắn vào tài khoản.

## 9. App mới nhưng backend cũ → dữ liệu bị bỏ

App mới gọi endpoint backend chưa có sẽ nhận 404. Với các hàng đợi đồng bộ, 404 được coi là lỗi vĩnh viễn nên **bỏ luôn dữ liệu**. Ví dụ: app 1.3.3+ đồng bộ ván game qua `POST /v1/games/rounds`; nếu backend chưa có endpoint này, điểm vẫn giữ trên máy nhưng không bao giờ lên bảng xếp hạng.

- Phát hiện: log backend có nhiều `route_not_found` với path mới.
- Sửa: deploy backend đúng phiên bản ngay ([deploy.md](deploy.md)). Dữ liệu đã bị bỏ trên máy không lấy lại được.
- Phòng tránh: luôn **deploy backend trước khi phát hành app** ([mobile-release.md](mobile-release.md#1-chuẩn-bị)).

## 10. App không báo có bản mới

- Banner dựa vào GitHub Release mới nhất; không phải pre-release hay draft.
- Màn *Check for updates* dựa vào backend: `node scripts/ops-check.mjs`, dòng `in-app update matches GitHub release`. Nếu lệch, upload APK theo [mobile-release.md](mobile-release.md#4-đưa-apk-lên-backend-cập-nhật-trong-app).
- Tải APK lỗi: log `release_store_apk_missing`, volume thiếu file. Upload lại APK.

## 11. Workflow `Android Release` lỗi

| Bước lỗi | Nguyên nhân thường gặp | Sửa |
|---|---|---|
| Validate tag version | Tag khác `version` trong `pubspec.yaml` | Xoá tag, bump qua PR, tag lại ([mobile-release.md](mobile-release.md#khi-có-sự-cố)) |
| Decode keystore / Build signed | Secret `KEYSTORE_BASE64`/mật khẩu sai hoặc hết hạn | [secrets.md](secrets.md#keystore-android), rồi `gh run rerun <id>` |
| Build | Lỗi code/phụ thuộc, sai phiên bản Flutter (`3.47.5`, khớp `mobile/.fvmrc`) | Chạy `flutter build apk` ở máy local để tái hiện, sửa qua PR, ra bản vá mới |
| Create GitHub Release | Tag đã có release | Ra bản vá mới |

`gh run view <id> --log-failed` để xem log bước lỗi.

## 12. Đĩa đầy

```bash
df -h / /home
docker system df
du -sh /var/lib/docker/containers/*/*-json.log 2>/dev/null | sort -h | tail
du -sh /home/beou/datadir/* ~/backups/expat8 2>/dev/null
```
Theo thứ tự an toàn: log docker không giới hạn (worker/dashboard) → image cũ (`docker image prune`, chỉ image không dùng) → backup cũ → log Postgres cũ. Chi tiết và cách phòng ở [maintenance.md](maintenance.md#dung-lượng-đĩa). **Không** xoá volume hay dữ liệu Postgres.

## 13. Nghi lộ secret hoặc bị xâm nhập

Làm ngay theo [secrets.md](secrets.md#khi-nghi-lộ-secret). Đổi secret trước, điều tra sau.
