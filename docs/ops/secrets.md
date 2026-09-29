# Secrets và quyền truy cập

Không bao giờ đưa giá trị thật vào repo, issue, PR, log hay chat. Thay đổi `.env` trên Z440 thì sao lưu bản mã hoá (ví dụ `age`/`gpg`) ra nơi an toàn.

## Danh mục

| Secret | Nằm ở | Ai dùng | Mất/lộ thì sao |
|---|---|---|---|
| `DATABASE_URL` (user/mật khẩu DB) | `.env` Z440 | backend, worker | Lộ: đọc/sửa toàn bộ dữ liệu |
| `EXPAT8_DASHBOARD_DATABASE_URL` | `.env` Z440 | dashboard (đọc DB trực tiếp) | Như trên |
| `APP_CREDENTIALS_JSON` | `.env` Z440 | backend: danh sách `{appId, secret, status}` được phép gọi API | Xem *Credential app* bên dưới |
| `APP_CREDENTIAL_APP_ID/SECRET` (mobile) | GitHub Actions secrets, biên dịch vào APK | app Android | Nằm trong APK, **coi như công khai** |
| `APP_CREDENTIAL_APP_ID/SECRET` (dashboard) | `.env` Z440 (`DASHBOARD_...`/biến của service dashboard) | dashboard | Gọi API như một app |
| `ADMIN_API_TOKENS` | `.env` Z440, danh sách phân tách bằng dấu phẩy | backend | Lộ: toàn quyền `/v1/admin/*` (duyệt nội dung, upload APK, đọc log người dùng) |
| `ADMIN_TOKEN` (dashboard) | `.env` Z440 | dashboard | Một token trong `ADMIN_API_TOKENS` |
| `LITELLM_API_KEY` | `.env` Z440 | backend, worker | Lộ: tốn tiền LLM |
| `KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` | GitHub Actions secrets + bản gốc offline | workflow Android Release | **Mất: không ra được bản cập nhật cho người đã cài.** Lộ: người khác ký được app giả mạo |
| `BACKEND_BASE_URL`, `NEW_WORD_TIMEOUT_SECONDS` | GitHub Actions secrets | workflow Android Release | Không nhạy cảm, để ở secrets cho tiện |
| Session người dùng | Bảng `user_sessions` (chỉ lưu SHA-256 của token) | backend | Token thô chỉ nằm trên điện thoại |
| Mật khẩu người dùng | `users.password_hash` (scrypt) | backend | |

### Credential app không phải bí mật thật

Secret của app mobile nằm trong APK, ai có APK đều trích ra được. Chữ ký HMAC chỉ chặn request ngẫu nhiên và replay, không chặn một kẻ tấn công quyết tâm. Lớp bảo vệ thật là: session người dùng (bearer token), admin token, rate limit, và việc backend kiểm tra dữ liệu. Vì vậy **đừng** dựa vào credential app để bảo vệ dữ liệu nhạy cảm.

### Dashboard không có đăng nhập

`expat8-dashboard` không có màn đăng nhập. Ai truy cập được cổng `3019` là có toàn quyền admin (dashboard tự gửi `ADMIN_TOKEN` và đọc DB trực tiếp). Cổng này chỉ được bind vào IP nội bộ của Z440. **Không** mở ra internet hay cấu hình reverse proxy public cho nó. Truy cập từ xa qua VPN hoặc SSH tunnel:

```bash
ssh -L 3019:<Z440_HOST>:3019 <Z440_SSH>   # rồi mở http://localhost:3019
```

## Xoay vòng

Nên làm định kỳ: admin token và LiteLLM key mỗi 6 tháng, hoặc khi có người rời nhóm. Credential app chỉ xoay khi cần, vì phải ra bản app mới.

### Credential app (mobile)

Backend tìm credential theo `appId` và chỉ chấp nhận `status: "active"`. Mỗi `appId` chỉ có một secret, nên muốn xoay vòng phải dùng **appId mới**. Làm sai thứ tự thì app đang dùng bị từ chối (400) và bỏ dữ liệu đồng bộ ([troubleshooting.md](troubleshooting.md#2-request-có-ký-bị-từ-chối-400-bad_request)).

1. Tạo secret mới: `openssl rand -base64 48`.
2. Thêm credential mới, **giữ** credential cũ `active`:
   ```json
   [{"appId":"expat8-mobile-app","secret":"<cũ>","status":"active"},
    {"appId":"expat8-mobile-app-2","secret":"<mới>","status":"active"}]
   ```
   Recreate `expat8-backend`. Kiểm tra bằng `ops-check.mjs` với credential mới.
3. Cập nhật GitHub secrets `APP_CREDENTIAL_APP_ID`/`APP_CREDENTIAL_SECRET` (`gh secret set APP_CREDENTIAL_SECRET`), rồi ra bản app mới ([mobile-release.md](mobile-release.md)).
4. Chờ phần lớn người dùng cập nhật (ít nhất 30 ngày). Log request không ghi `app_id`, nên theo dõi bằng lượt tải bản mới: `gh api repos/duvu/expat8/releases --jq '.[] | "\(.tag_name) \(.assets[] | select(.name=="app-release.apk") | .download_count)"'`.
5. Đổi credential cũ sang `"status":"disabled"`, recreate backend. Máy còn bản app cũ sẽ không đồng bộ được cho đến khi cập nhật (vẫn học offline).

Credential của dashboard xoay giống vậy nhưng không cần ra app: thêm credential mới, đổi biến của dashboard, recreate dashboard, rồi tắt credential cũ.

### Admin token

```bash
NEW=$(openssl rand -hex 32)
# 1. ADMIN_API_TOKENS=<cũ>,<NEW>   → recreate expat8-backend
# 2. ADMIN_TOKEN=<NEW> cho dashboard, ops.env của người vận hành → recreate expat8-dashboard
# 3. ADMIN_API_TOKENS=<NEW>          → recreate expat8-backend
```

### LiteLLM key

Tạo key mới trên LiteLLM, đổi `LITELLM_API_KEY` trong `.env`, `docker compose up -d --force-recreate expat8-backend expat8-worker`, kiểm tra log worker không còn lỗi `litellm_*` 401, rồi thu hồi key cũ.

### Mật khẩu database

Postgres và pgbouncer **dùng chung** với dự án khác. Chỉ đổi mật khẩu của user riêng của Expat8; nếu Expat8 đang dùng user chung thì phải bàn với các dự án kia trước.

1. `ALTER ROLE <expat8_user> WITH PASSWORD '<mới>';`
2. Cập nhật cấu hình xác thực của pgbouncer nếu nó lưu mật khẩu (`/home/beou/datadir/pgbouncer`), rồi reload pgbouncer.
3. Đổi `DATABASE_URL` và `EXPAT8_DASHBOARD_DATABASE_URL`, recreate `expat8-backend expat8-worker expat8-dashboard`.
4. Cập nhật `~/.config/expat8/backup.env` nếu có.

### Đăng xuất tất cả người dùng

Session không tự hết hạn; chỉ mất hiệu lực khi đăng xuất hoặc bị thu hồi. Thu hồi tất cả (khi lộ DB hoặc nghi session bị đánh cắp):

```sql
UPDATE user_sessions
SET revoked_at = to_char(now() AT TIME ZONE 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
WHERE revoked_at IS NULL;
```

Thu hồi của một người: thêm `AND user_id = '<user_id>'`. Người dùng phải đăng nhập lại; dữ liệu chưa đồng bộ trên máy vẫn giữ và được gửi sau khi đăng nhập.

## Keystore Android

- Bản gốc `release.jks` và các mật khẩu phải lưu **offline ở hai nơi** (ví dụ trình quản lý mật khẩu của nhóm và một bản mã hoá trên ổ ngoài). `KEYSTORE_BASE64` trên GitHub **không** đọc ra được, nên không phải là bản backup.
- Mất keystore: người đã cài phải gỡ app (mất dữ liệu chưa đồng bộ) để cài bản ký bằng khoá mới. Khi lên Play Store thì dùng Play App Signing để tránh rủi ro này.
- Đặt lại secret trên GitHub:
  ```bash
  base64 -w0 release.jks | gh secret set KEYSTORE_BASE64
  gh secret set STORE_PASSWORD; gh secret set KEY_ALIAS; gh secret set KEY_PASSWORD
  ```
- Kiểm tra khoá của một APK: `apksigner verify --print-certs app-release.apk` (SHA-256 phải trùng giữa các bản).

## Khi nghi lộ secret

1. **Chặn ngay:** xoay secret bị lộ theo mục trên. Với admin token hoặc DB thì làm trong vài phút, không cần đợi.
2. Lộ DB: đổi mật khẩu DB **và** đăng xuất tất cả người dùng.
3. Lộ keystore: không thu hồi được. Báo nhóm, cân nhắc chuyển khoá khi lên Play Store.
4. Lộ secret app mobile: chấp nhận được (vốn coi là công khai). Xoay khi có bằng chứng bị lạm dụng.
5. Xem log để biết phạm vi: request admin lạ (`docker logs --since 7d expat8-backend 2>&1 | jq -Rc 'fromjson? | select(.path? // "" | startswith("/v1/admin"))'`), đăng nhập bất thường.
6. Ghi sự cố: thời điểm phát hiện, secret nào, đã xoay lúc nào, dữ liệu nào có thể bị ảnh hưởng.

## Quyền truy cập cần có

| Việc | Cần |
|---|---|
| Deploy, backup, xử lý sự cố | SSH vào Z440, quyền `docker`, đọc `~/deployment/worker-z440/.env` |
| Push image | Tài khoản registry nội bộ |
| Release app | Quyền push tag trên `duvu/expat8`, xem Actions |
| Đổi secrets build | Admin repo GitHub |
| Dashboard | VPN/SSH tới mạng nội bộ Z440 |
