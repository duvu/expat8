# Runbook deploy — prod-readiness 2026-09-28

Áp dụng cho branch `prod-readiness/20260928` trên Z440 (`~/deployment/worker-z440`). Chạy lần lượt từng bước; dừng lại nếu một bước lỗi.

## 0. Điều kiện trước

- PR đã merge, CI xanh.
- Biết IP của reverse proxy đứng trước cổng `18787` (máy phục vụ `expat8.x51.vn`).

## 1. Build và push image

```bash
TAG=$(date +%Y%m%d.%H%M)
docker build -t docker.x51.vn/x-ai/expat8-backend:$TAG backend
docker push docker.x51.vn/x-ai/expat8-backend:$TAG
```

## 2. Backup DB

```bash
cd ~/deployment/worker-z440
docker compose exec -T <postgres-service> pg_dump -U <user> -Fc <db> > expat8-$(date +%Y%m%d-%H%M).dump
```

## 3. Cấu hình `expat8-backend`

Trong `docker-compose.yml` (service `expat8-backend`):

```yaml
    image: docker.x51.vn/x-ai/expat8-backend:<TAG>
    environment:
      TRUST_PROXY: "<IP reverse proxy>"   # không dùng "true": cổng 18787 cũng mở trong mạng nội bộ
      # AUTH_RATE_LIMIT_IP: "60"          # mặc định
```

Làm tương tự cho `expat8-worker` (cùng image `<TAG>`).

## 4. Migrate

Lần đầu tiên sẽ ghi baseline và chạy lại toàn bộ migration (đều idempotent, đã test trên PostgreSQL 16), gồm migration sửa `loop_completed`.

```bash
docker compose run --rm expat8-backend npm run migrate
```

Kết quả mong đợi: dòng log `db.migration.complete` với `applied_count` > 0. Chạy lại lần 2 phải ra `applied_count: 0`.

## 5. Recreate và kiểm tra

```bash
docker compose up -d --force-recreate expat8-backend expat8-worker
curl -sS http://<INTERNAL_HOST>:18787/health/ready     # {"ok":true,"db":"ok"}
```

- Đăng ký/đăng nhập một tài khoản thử trên app → không còn lỗi 500.
- Hoàn thành một vòng speaking drill → dashboard `/ops` loop health tăng `loop_completion_count`.
- Gửi sign-in sai từ hai mạng khác nhau (Wi-Fi, 4G) → mỗi mạng có `X-RateLimit-Remaining` riêng.

## 6. Rollback

```bash
# đổi image về tag cũ trong docker-compose.yml, rồi:
docker compose up -d --force-recreate expat8-backend expat8-worker
```

Các migration chỉ thêm/nới ràng buộc, nên image cũ vẫn chạy được trên schema mới. Chỉ khôi phục bản dump ở bước 2 khi dữ liệu bị hỏng.
