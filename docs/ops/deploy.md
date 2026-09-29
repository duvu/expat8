# Deploy backend, worker, dashboard

Áp dụng cho production trên Z440 (`~/deployment/worker-z440`). Chạy từng bước theo thứ tự, **dừng lại nếu một bước lỗi**. Thời gian thường: 15–20 phút; API gián đoạn vài giây lúc recreate (app offline-first nên người học không mất dữ liệu).

## 0. Trước khi bắt đầu

- [ ] Code đã merge vào `main`, và đã chạy kiểm tra ở máy local (repo không còn CI cho PR):
  ```bash
  cd backend && npm run lint && npm test
  cd ../expat8-dashboard && npm run lint && npm test && npm run build   # nếu dashboard đổi
  ```
- [ ] Có backup DB trong 24h qua ([backup-restore.md](backup-restore.md)); nếu không, chạy `scripts/ops/backup.sh` ngay.
- [ ] Đọc migration mới trong `backend/db/migrations/` kể từ lần deploy trước: `git diff <tag-cũ>..main --stat -- backend/db/migrations`. Migration nào xoá cột/bảng thì image cũ **không** chạy được sau đó; phải lên kế hoạch rollback bằng restore.
- [ ] Nếu sắp phát hành app cần endpoint mới: deploy backend này **trước** khi tag app.

## 1. Build và push image

Tag image dạng `YYYYMMDD.HHMM`, dùng chung một tag cho backend và worker.

```bash
git checkout main && git pull
TAG=$(date +%Y%m%d.%H%M)
docker build -t <REGISTRY>/expat8-backend:$TAG backend
docker push <REGISTRY>/expat8-backend:$TAG

# chỉ khi dashboard có thay đổi
docker build -t <REGISTRY>/expat8-dashboard:$TAG expat8-dashboard
docker push <REGISTRY>/expat8-dashboard:$TAG
```

Registry lỗi (502 v.v.) thì chuyển image thẳng sang Z440:

```bash
docker save <REGISTRY>/expat8-backend:$TAG | gzip | ssh <Z440_SSH> 'gunzip | docker load'
```

## 2. Chọn image trên Z440

Trong `~/deployment/worker-z440/.env` (ưu tiên hơn sửa default trong compose, và giữ backend/worker cùng tag):

```dotenv
EXPAT8_BACKEND_IMAGE=<REGISTRY>/expat8-backend:<TAG>
EXPAT8_WORKER_IMAGE=<REGISTRY>/expat8-backend:<TAG>
EXPAT8_DASHBOARD_IMAGE=<REGISTRY>/expat8-dashboard:<TAG>   # nếu có build mới
```

Ghi lại tag cũ để rollback: `docker inspect --format '{{.Config.Image}}' expat8-backend expat8-worker expat8-dashboard`.

### Cấu hình bắt buộc

Đặt trong `.env` (được nạp vào container qua `env_file`) hoặc khối `environment:` của `expat8-backend`:

| Biến | Giá trị production | Vì sao |
|---|---|---|
| `TRUST_PROXY` | IP của reverse proxy trước cổng 18787 (hoặc số hop `1`) | Không đặt thì mọi người dùng chung IP proxy, giới hạn đăng nhập 60/phút thành giới hạn toàn hệ thống. Không dùng `true` vì cổng 18787 mở trong mạng nội bộ |
| `MIGRATE_ON_START` | `false` (mặc định) | Production chạy migrate thủ công ở bước 3 |
| `APP_CREDENTIALS_JSON`, `ADMIN_API_TOKENS`, `DATABASE_URL`, `LITELLM_*` | xem [secrets.md](secrets.md) | |

Đầy đủ các biến: `backend/.env.example` và `backend/src/config.js`.

## 3. Migrate database

Migration giữ `pg_advisory_lock` theo **session**, nên phải kết nối **thẳng vào Postgres**, không qua pgbouncer (pool mode `transaction` có thể làm lock rơi vào connection khác và bị treo). Dùng URL giống `DATABASE_URL` nhưng host là service `postgres`, cổng `5432`:

```bash
cd ~/deployment/worker-z440
docker compose run --rm --no-deps \
  -e DATABASE_URL='postgres://<user>:<password>@postgres:5432/<expat8_db>' \
  expat8-backend npm run migrate
```

Kết quả đúng: dòng log `db.migration.complete` với `applied_count` ≥ 0. Chạy lại lần 2 phải ra `applied_count: 0`. Lần đầu trên DB có từ trước khi có runner, nó ghi baseline và chạy lại toàn bộ migration (đều idempotent, đã test trên PostgreSQL 16).

Mỗi migration chạy trong transaction riêng: lỗi ở file nào thì file đó rollback, các file trước vẫn giữ. Có `db.migration.failed` thì **dừng**, đừng recreate; xem [troubleshooting.md](troubleshooting.md#7-migrate-lỗi-hoặc-treo).

## 4. Recreate

```bash
docker compose up -d --force-recreate expat8-backend expat8-worker
docker compose up -d --force-recreate expat8-dashboard   # nếu đổi dashboard
docker compose ps expat8-backend expat8-worker expat8-dashboard
```

`expat8-backend` phải chuyển sang `healthy` trong khoảng 1 phút. Worker dừng êm: nhận SIGTERM, chờ tick đang chạy xong (`article_worker_shutdown_clean`); job đang dở vẫn nằm trong PostgreSQL và được xử lý lại.

## 5. Kiểm tra sau deploy

```bash
set -a; . ~/.config/expat8/ops.env; set +a     # BACKEND_BASE_URL, APP_CREDENTIAL_*, ADMIN_TOKEN
node scripts/smoke-deployed-backend.mjs
node scripts/ops-check.mjs
docker compose logs --since 5m expat8-backend expat8-worker | grep '"level":"error"'   # phải rỗng
```

Kiểm tra tay trên app (bản mới nhất):

- [ ] Đăng nhập tài khoản thử, lấy thẻ học mới, đánh giá thẻ → không có lỗi.
- [ ] Chơi 1 ván Word Blaster khi đã đăng nhập → bảng xếp hạng tuần có điểm.
- [ ] Dashboard mở được `/ops`, `/system/pipeline`.
- [ ] Sau khi đặt `TRUST_PROXY`: đăng nhập sai từ 2 mạng khác nhau (Wi-Fi, 4G) → mỗi mạng thấy `X-RateLimit-Remaining` riêng.

Ghi tag đã deploy vào mục *Việc còn tồn* trong [README.md](README.md) hoặc nhật ký vận hành của nhóm.

## 6. Rollback

Image lỗi nhưng dữ liệu không hỏng (trường hợp thường gặp):

```bash
# đặt lại EXPAT8_BACKEND_IMAGE / EXPAT8_WORKER_IMAGE về tag cũ trong .env
docker compose up -d --force-recreate expat8-backend expat8-worker
node scripts/ops-check.mjs
```

Migration trong repo chỉ thêm bảng/cột hoặc nới ràng buộc, nên image cũ chạy được trên schema mới; **không** cần hạ schema. Chỉ khôi phục bản dump khi dữ liệu bị hỏng ([backup-restore.md](backup-restore.md#khôi-phục-production)). Việc này làm mất dữ liệu ghi sau thời điểm dump, và app sẽ tự gửi lại các sự kiện còn trong hàng đợi.

## Worker

- Chạy cùng image với backend, lệnh `npm run start:worker`. Mỗi tick (mặc định 1 giây, `ARTICLE_WORKER_INTERVAL_MS`) xử lý lần lượt: bài viết → tách đoạn passage → làm giàu passage → từ người dùng gửi. Hai tick không bao giờ chạy chồng nhau.
- Job lỗi được thử lại tối đa `ARTICLE_WORKER_MAX_ATTEMPTS` (mặc định 3) rồi chuyển trạng thái lỗi (`processing_failed`, `failed`).
- Dừng worker không mất việc: hàng đợi nằm trong PostgreSQL.
- Scheduler sinh từ vựng (`VOCAB_SCHEDULER_*`) chạy trong tiến trình **backend**, có khoá `scheduler_locks` nên chạy nhiều bản backend vẫn an toàn.

## Giới hạn khi mở rộng

Hiện chỉ chạy **một** bản `expat8-backend`. Nếu chạy nhiều bản sau load balancer:

- Rate limit đăng nhập nằm trong bộ nhớ từng tiến trình, nên giới hạn thực tế nhân theo số bản.
- Nonce chống replay đã lưu trong PostgreSQL (bảng `nonces`), an toàn khi chạy nhiều bản.
- APK và log archive nằm trên volume cục bộ, nên cần volume dùng chung.

## Local (docker compose trong repo)

Dùng cho phát triển, không phải production:

```bash
LITELLM_API_KEY=... docker compose up --build -d   # MIGRATE_ON_START=true, tự migrate khi khởi động
curl http://localhost:8787/health
docker compose down                                 # không dùng -v trừ khi muốn xoá DB local
```

> Đã kiểm chứng (2026-09-29): migrate trên PostgreSQL 16 sạch (30 migration, chạy lại ra 0), smoke/ops-check chạy với backend thật. Các bước trên Z440 lấy theo `docker-compose.yml` của thư mục deploy; tên DB/URL thật nằm trong `.env` ở đó.
