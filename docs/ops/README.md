# Vận hành Expat8

Bộ tài liệu dành cho người trực vận hành: deploy, release app, backup, giám sát, xử lý sự cố, secrets và bảo trì. Mọi lệnh ở đây đã được chạy thử (xem ghi chú "Đã kiểm chứng" trong từng trang); giá trị thật của production (IP, mật khẩu, token) **không** ghi vào repo, dùng placeholder `<...>`.

| Trang | Dùng khi |
|---|---|
| [deploy.md](deploy.md) | Đưa bản backend/worker/dashboard mới lên production, migrate, rollback |
| [mobile-release.md](mobile-release.md) | Phát hành app Android (tag → build → GitHub Release → cập nhật trong app) |
| [backup-restore.md](backup-restore.md) | Backup hằng đêm, khôi phục DB, diễn tập restore |
| [monitoring.md](monitoring.md) | Theo dõi hằng ngày, cảnh báo tự động, đọc log |
| [troubleshooting.md](troubleshooting.md) | Có sự cố: tra theo triệu chứng |
| [secrets.md](secrets.md) | Danh mục secrets, cách xoay vòng, xử lý khi lộ |
| [maintenance.md](maintenance.md) | Việc định kỳ, dung lượng đĩa, yêu cầu xoá tài khoản |

## Hệ thống production trong 1 phút

```text
App Android ──HTTPS──> expat8.x51.vn (reverse proxy, máy khác)
                           │
                           ▼  <Z440_HOST>:18787
┌──────────────── Z440: ~/deployment/worker-z440 (docker compose) ────────────────┐
│ expat8-backend   API Express, image <REGISTRY>/expat8-backend:<TAG>            │
│ expat8-worker    cùng image, `npm run start:worker` (bài viết, passage, từ gửi) │
│ expat8-dashboard Next.js admin, cổng <Z440_HOST>:3019                           │
│ pgbouncer        pool mode transaction, dùng chung với các dự án khác           │
│ postgres         TimescaleDB-HA PG16 (container postgres-z440), dùng chung      │
└────────────────────────────────────────────────────────────────────────────────┘
       LiteLLM (LITELLM_BASE_URL) — chỉ worker/scheduler gọi, không nằm trên đường học
```

| Thành phần | Nơi ở | Ghi chú |
|---|---|---|
| Cấu hình deploy | `~/deployment/worker-z440/docker-compose.yml` + `.env` | Không nằm trong repo này |
| Dữ liệu chính | Database Expat8 trên `postgres` | Backend đi qua `pgbouncer` |
| APK cho cập nhật trong app | volume `expat8-releases` (`/data/releases`) | Giữ tối đa 5 bản/nền tảng |
| Log gửi từ app | volume `expat8-log-archives` (`/data/log-archives`) | Xem ở dashboard `/ops/logs` |
| Bản build Android | GitHub Releases `duvu/expat8` | Workflow `Android Release` |
| Secrets build Android | GitHub → Settings → Secrets → Actions | Xem [secrets.md](secrets.md) |

App là **offline-first**: khi backend chết, người học vẫn học, chơi game, luyện nói; dữ liệu xếp hàng trên máy và tự đồng bộ khi backend sống lại. Vì vậy sự cố backend ít khi là "mất dữ liệu" mà là "chậm đồng bộ"; ngoại lệ quan trọng xem mục *Backend cũ hơn app* trong [troubleshooting.md](troubleshooting.md#9-app-mới-nhưng-backend-cũ--dữ-liệu-bị-bỏ).

## Công cụ trong repo

| Lệnh | Việc |
|---|---|
| `node scripts/ops-check.mjs` | Kiểm tra nhanh: health, DB, hàng đợi xử lý nội dung, phiên bản cập nhật trong app khớp GitHub. Exit 1 nếu có lỗi → dùng cho cron |
| `node scripts/admin-request.mjs <METHOD> <PATH> ...` | Gọi API có ký HMAC (admin hoặc thường), ví dụ upload APK, retry bài lỗi |
| `node scripts/smoke-deployed-backend.mjs` | Smoke test sau deploy (health, ký HMAC, lấy thẻ học) |
| `scripts/ops/backup.sh` | Backup DB + APK, kiểm tra dump, xoá bản cũ |
| `backend/db/ops/delete_user.sql` | Xoá vĩnh viễn một tài khoản (mặc định chạy thử rồi rollback) |

`<repo>` trong tài liệu là bản clone repo này trên máy vận hành (Z440 hoặc máy của bạn), cập nhật bằng `git pull` trước khi dùng. Các script Node cần Node >= 22 và `BACKEND_BASE_URL`, `APP_CREDENTIAL_APP_ID`, `APP_CREDENTIAL_SECRET` và (với API admin) `ADMIN_TOKEN`. Nên để trong một file env không commit, ví dụ `~/.config/expat8/ops.env`, rồi `set -a; . ~/.config/expat8/ops.env; set +a`.

## Nguyên tắc

1. **Backend trước, app sau.** Tính năng app cần endpoint mới thì deploy backend (kèm migrate) *trước* khi phát hành app.
2. **Backup trước mọi migrate.** Không có dump mới trong 24h thì không deploy.
3. **Không sửa tag đã phát hành.** Build lỗi thì sửa và ra bản vá mới (`1.3.5`), không dời tag.
4. **Backend và worker luôn cùng một image tag.**
5. **Không đưa secrets vào repo, issue, PR hay log.**
6. Postgres và pgbouncer **dùng chung với dự án khác**: không restart, đổi cấu hình hay đổi mật khẩu khi chưa báo các dự án đó.

## Việc còn tồn (cập nhật 2026-09-29)

Các điểm sau được ghi nhận từ bản cấu hình `~/deployment/worker-z440` trên máy dev; cần xác nhận trên Z440:

- [ ] **Production còn chạy image cũ** (backend `20260525.2039`, worker `20260523.1454`, lệch nhau). Chưa có bản prod-readiness (scrypt, rate limit, migration runner) và các endpoint game (`/v1/games/*`) mà app 1.3.3+ cần. Làm theo [deploy.md](deploy.md), sau đó ghi lại tag đã deploy vào đây.
- [ ] `TRUST_PROXY` chưa được đặt cho `expat8-backend` (xem [deploy.md](deploy.md#cấu-hình-bắt-buộc)).
- [ ] Khi phát hành 1.3.3/1.3.4 chưa upload APK lên backend, nên màn *Check for updates* trong app chưa thấy bản mới (kiểm tra bằng `ops-check.mjs`) (xem [mobile-release.md](mobile-release.md#4-đưa-apk-lên-backend-cập-nhật-trong-app)).
- [ ] `expat8-worker` và `expat8-dashboard` chưa giới hạn log docker (xem [maintenance.md](maintenance.md#giới-hạn-log-docker)).
- [ ] Chưa có cron backup và cron `ops-check` (xem [backup-restore.md](backup-restore.md), [monitoring.md](monitoring.md)).
- [ ] Chưa có API xoá tài khoản cho người dùng tự làm; hiện xử lý thủ công theo [maintenance.md](maintenance.md#yêu-cầu-xoá-tài-khoản).

### Rủi ro đã biết (cần sửa code)

- **Lỗi xác thực app trả 400 nên app bỏ dữ liệu.** Backend trả `400` cho chữ ký sai hoặc giờ lệch (`backend/src/app.js`, `appCredentialGuard`), trong khi app coi 400 là lỗi vĩnh viễn và xoá sự kiện khỏi hàng đợi (`mobile/lib/src/data/word_repository.dart`, `_isPermanentSyncFailure`). Một điện thoại chỉnh sai giờ hơn 5 phút sẽ mất lịch sử học chưa đồng bộ. Đề xuất: backend trả `401` cho lỗi xác thực (cập nhật `contracts/api.md`) để app giữ lại và thử lại.
- **Endpoint mới chưa deploy → 404 → app bỏ dữ liệu** (xem [troubleshooting.md](troubleshooting.md#9-app-mới-nhưng-backend-cũ--dữ-liệu-bị-bỏ)). Hiện chỉ phòng bằng quy trình "backend trước, app sau".
- **Dashboard admin không có đăng nhập.** Ai vào được cổng 3019 là có toàn quyền admin; hiện chỉ dựa vào việc cổng chỉ mở trong mạng nội bộ ([secrets.md](secrets.md#dashboard-không-có-đăng-nhập)). Đề xuất: thêm đăng nhập (ví dụ basic auth ở reverse proxy nội bộ, hoặc middleware Next.js).
- **Worker ghi log `article_processing_backlog` mỗi giây** (~86.000 dòng/ngày ở mức `info`), cộng thêm log docker chưa giới hạn. Đề xuất: chỉ ghi khi số lượng thay đổi, hoặc hạ xuống `debug`.
