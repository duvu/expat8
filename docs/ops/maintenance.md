# Bảo trì định kỳ

## Lịch

| Tần suất | Việc | Chi tiết |
|---|---|---|
| Hằng ngày | Xem `ops-check`, dashboard `/ops` và `/system/pipeline`, lỗi log 24h | [monitoring.md](monitoring.md#theo-dõi-hằng-ngày-5-phút) |
| Hằng tuần | Backup mới nhất có từ đêm qua, dung lượng hợp lý | [backup-restore.md](backup-restore.md) |
| Hằng tuần | Dung lượng đĩa Z440 | [Dung lượng đĩa](#dung-lượng-đĩa) |
| Hằng tuần | Duyệt nội dung chờ: `/review`, `/articles`, `/memorization/passages` trên dashboard | Nội dung admin chỉ lên app sau khi duyệt |
| Hằng tháng | Diễn tập restore | [backup-restore.md](backup-restore.md#diễn-tập-restore-mỗi-tháng) |
| Hằng tháng | Dọn image cũ, kiểm tra bảng lớn nhất | [Dọn dẹp](#dọn-image-docker-cũ), [Database](#database) |
| Hằng tháng | Cập nhật phụ thuộc có lỗ hổng | [Phụ thuộc](#phụ-thuộc) |
| 6 tháng | Xoay admin token, LiteLLM key; xem lại danh sách người có quyền | [secrets.md](secrets.md#xoay-vòng) |
| Khi có yêu cầu | Xoá tài khoản người dùng | [Yêu cầu xoá tài khoản](#yêu-cầu-xoá-tài-khoản) |

## Hệ thống tự dọn

| Dữ liệu | Cơ chế | Cấu hình |
|---|---|---|
| Nonce chống replay (`nonces`) | Backend xoá bản hết hạn mỗi phút | `APP_CREDENTIAL_NONCE_TTL_SECONDS` (300) |
| Log gửi từ app | Xoá sau 3 ngày hoặc khi tổng vượt 100 MB | `LOG_ARCHIVE_RETENTION_DAYS`, `LOG_ARCHIVE_MAX_TOTAL_BYTES` |
| APK cho cập nhật trong app | Giữ 5 bản mới nhất mỗi nền tảng | cố định trong code |
| Log backend (docker) | 3 file × 10 MB | khối `logging:` của `expat8-backend` |
| Backup | Xoá bản cũ hơn 14 ngày | `RETENTION_DAYS` của `backup.sh` |
| Log trên điện thoại | App tự xoá log cũ trong ObjectBox mỗi 5 phút | trong app |

Không tự dọn: session đã thu hồi (`user_sessions`), `study_events` và các bảng lịch sử khác (cố ý giữ, vì là dữ liệu học), log docker của worker và dashboard (xem dưới).

## Giới hạn log docker

`expat8-worker` và `expat8-dashboard` chưa có giới hạn log, trong khi worker ghi `article_processing_backlog` mỗi giây. Thêm vào hai service này trong `~/deployment/worker-z440/docker-compose.yml`, giống `expat8-backend`:

```yaml
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

Rồi `docker compose up -d --force-recreate expat8-worker expat8-dashboard`. Log cũ trước khi recreate sẽ bị xoá cùng container.

## Dung lượng đĩa

```bash
df -h / /home
docker system df
sudo du -sh /var/lib/docker/containers/*/*-json.log 2>/dev/null | sort -h | tail -5
du -sh /home/beou/datadir/pgdata /home/beou/datadir/wal /home/beou/datadir/logs ~/backups/expat8
```

Trên 85% thì dọn theo thứ tự an toàn:

1. Log docker quá lớn: đặt giới hạn log như trên rồi recreate container.
2. Image không dùng: [Dọn image](#dọn-image-docker-cũ).
3. Backup cũ trên máy, **sau khi** chắc bản ngoài máy còn đủ.
4. Log Postgres cũ trong `/home/beou/datadir/logs` (Postgres đã tự xoay file theo ngày).

**Không** xoá `pgdata`, `wal`, volume docker, hay chạy `docker system prune --volumes`. Máy chạy nhiều dự án.

## Dọn image docker cũ

Giữ lại image đang chạy và **một** bản trước đó để rollback:

```bash
docker images '<REGISTRY>/expat8-backend' --format '{{.CreatedAt}}\t{{.Tag}}\t{{.ID}}' | sort -r
docker inspect --format '{{.Config.Image}}' expat8-backend expat8-worker expat8-dashboard
docker rmi <REGISTRY>/expat8-backend:<tag-cũ>      # từng tag, trừ 2 bản mới nhất
docker image prune -f                             # chỉ image không có tag
```

## Database

Autovacuum mặc định của Postgres là đủ. Kiểm tra hằng tháng:

```bash
# bảng lớn nhất
docker compose exec -T postgres psql -U <user> -d <expat8_db> -c "
select relname, pg_size_pretty(pg_total_relation_size(relid)) total, n_live_tup, n_dead_tup, last_autovacuum
from pg_stat_user_tables order by pg_total_relation_size(relid) desc limit 10;"
```

Bảng có `n_dead_tup` lớn hơn nhiều so với `n_live_tup` mà `last_autovacuum` đã cũ thì chạy `VACUUM (ANALYZE) <bảng>;`, việc này không khoá bảng. Không chạy `VACUUM FULL` trên production vì nó khoá bảng.

Dọn session đã thu hồi quá 90 ngày (tuỳ chọn):

```sql
DELETE FROM user_sessions
WHERE revoked_at IS NOT NULL
  AND revoked_at < to_char(now() AT TIME ZONE 'utc' - interval '90 days', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
```

## Yêu cầu xoá tài khoản

Chưa có API để người dùng tự xoá. Khi nhận yêu cầu (qua kênh hỗ trợ trong [privacy-policy.md](../privacy-policy.md)):

1. Xác minh người yêu cầu là chủ tài khoản (ví dụ yêu cầu gửi từ đúng email/identifier đã đăng ký).
2. Tìm `user_id`:
   ```sql
   SELECT id, identifier, display_name, created_at FROM users WHERE identifier = '<identifier>';
   ```
3. Backup trước: `RETENTION_DAYS=3650 ~/bin/expat8-backup.sh`. Bản backup này vẫn chứa dữ liệu người dùng; nó tự hết hạn theo lịch giữ backup, và cần ghi rõ điều này khi trả lời người dùng.
4. Chạy thử (mặc định rollback, in ra những gì sẽ xoá):
   ```bash
   docker compose exec -T postgres psql -U <user> -d <expat8_db> -v user_id=<user_id> -f - < <repo>/backend/db/ops/delete_user.sql
   ```
5. Xoá thật:
   ```bash
   docker compose exec -T postgres psql -U <user> -d <expat8_db> -v user_id=<user_id> -v confirm=yes -f - < <repo>/backend/db/ops/delete_user.sql
   ```
   Kết quả đúng: `remaining_user_rows = 0` và `deleted (committed)`.
6. Trả lời người dùng và ghi lại (ngày, `user_id`, người thực hiện; không ghi nội dung dữ liệu).

**Người dùng không có tài khoản** (chỉ học ẩn danh): app không hiển thị device ID. Nhờ họ gửi log (Menu → Tools & settings → Logs → **Send logs to server**), lấy `source_device_id` của bản log đó ở dashboard `/ops/logs`, rồi chạy các bước 3–6 với `-v device_id=<device_id>` thay cho `-v user_id=...`.

Script xoá: tài khoản, session, trình độ, lịch sử học/luyện nói/game/bài thi, trạng thái từ, từ đã gửi, nội dung người dùng sở hữu (bài viết, passage, video shadowing), cùng dữ liệu ẩn danh trên các thiết bị từng đăng nhập tài khoản đó. Nội dung admin mà người đó từng duyệt được giữ lại, chỉ xoá tham chiếu tới người duyệt. Dữ liệu trên điện thoại của họ không bị ảnh hưởng: nhắc họ gỡ app hoặc xoá dữ liệu app.

Bản ghi âm luyện nói **không bao giờ** lên server ([20260509-speaking-audio-privacy.md](../20260509-speaking-audio-privacy.md)), nên không cần xoá ở server.

## Phụ thuộc

```bash
cd backend && npm audit --omit=dev && npm outdated
cd ../expat8-dashboard && npm audit --omit=dev
cd ../mobile && flutter pub outdated
```

- Lỗ hổng `high`/`critical` trong phụ thuộc chạy production: sửa trong tuần, deploy theo quy trình thường.
- Nâng Flutter: đổi đồng thời `mobile/.fvmrc`, `environment.flutter` trong `mobile/pubspec.yaml` và `flutter-version` trong `.github/workflows/android-release.yml`. Chạy `flutter test` rồi build thử trước khi ra bản.
- Node của backend cần >= 22 (`backend/package.json` → `engines`); image base nằm trong `backend/Dockerfile`.

> Đã kiểm chứng (2026-09-29): `delete_user.sql` chạy trên PostgreSQL 16 với dữ liệu tạo qua API thật (2 tài khoản có bài viết, passage, đoạn, tiến độ, ván game, cùng một thiết bị ẩn danh). Chạy thử thì rollback; chạy thật chỉ xoá đúng tài khoản hoặc thiết bị chỉ định, dữ liệu còn lại giữ nguyên; `user_id` không tồn tại thì không xoá gì; thiếu tham số thì dừng, không làm gì.
