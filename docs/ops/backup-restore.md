# Backup và khôi phục

## Cần backup những gì

| Dữ liệu | Nơi ở | Mất thì sao | Cách backup |
|---|---|---|---|
| Database Expat8 (tài khoản, lịch sử học, SRS, bài viết, passage, game, bài thi) | `postgres` trên Z440 | **Mất vĩnh viễn** dữ liệu người học đã đồng bộ | `pg_dump` hằng đêm |
| APK cho cập nhật trong app | volume `expat8-releases` | Tải lại từ GitHub Releases rồi upload lại | tar hằng đêm (nhỏ, tiện) |
| Log gửi từ app | volume `expat8-log-archives` | Chỉ mất log chẩn đoán cũ (tự xoá sau 3 ngày) | Không cần |
| Cấu hình deploy | `~/deployment/worker-z440/docker-compose.yml`, `.env` | Phải dựng lại cấu hình bằng tay | Sao lưu mã hoá khi thay đổi ([secrets.md](secrets.md)) |
| Keystore ký Android | Ngoài hệ thống (bản gốc) + secret `KEYSTORE_BASE64` | **Không thể ra bản cập nhật** cho người đã cài | Lưu offline, 2 nơi ([secrets.md](secrets.md#keystore-android)) |

Dữ liệu chỉ nằm trên điện thoại (bản ghi luyện nói, sự kiện chưa đồng bộ) không nằm trong phạm vi backup server.

## Backup tự động hằng đêm

Script `scripts/ops/backup.sh` dump DB **thẳng từ container Postgres** (không qua pgbouncer), kiểm tra dump bằng `pg_restore --list` (dump hỏng thì báo lỗi và giữ nguyên các bản cũ), nén volume APK, rồi xoá bản cũ hơn `RETENTION_DAYS`.

Cài trên Z440:

```bash
mkdir -p ~/bin ~/backups/expat8
cp <repo>/scripts/ops/backup.sh ~/bin/expat8-backup.sh && chmod +x ~/bin/expat8-backup.sh
cat > ~/.config/expat8/backup.env <<'EOF'
PG_USER=<user có quyền đọc DB expat8>
PG_DB=<tên DB expat8>
BACKUP_DIR=/home/beou/backups/expat8
RETENTION_DAYS=14
EOF
chmod 600 ~/.config/expat8/backup.env
crontab -e
```

```cron
# 02:30 hằng đêm; log để kiểm tra
30 2 * * * set -a; . $HOME/.config/expat8/backup.env; set +a; $HOME/bin/expat8-backup.sh >> $HOME/backups/expat8/backup.log 2>&1 || echo "expat8 backup FAILED" | <lệnh gửi cảnh báo>
```

Tên volume APK mặc định là `worker-z440_expat8-releases`; kiểm tra bằng `docker volume ls | grep expat8-releases` và đặt `RELEASES_VOLUME` nếu khác.

**Chép ra ngoài máy.** Backup nằm cùng ổ với DB thì không chống được hỏng ổ hay mất máy. Đồng bộ `~/backups/expat8` sang máy khác hoặc object storage mỗi ngày (ví dụ `rclone copy`/`rsync` trong cron lúc 03:30).

Kiểm tra hằng tuần: `tail ~/backups/expat8/backup.log` và `ls -lh ~/backups/expat8 | tail`. Bản mới nhất phải có từ đêm qua và dung lượng không tụt bất thường.

### Backup trước khi deploy hoặc thao tác rủi ro

```bash
set -a; . ~/.config/expat8/backup.env; set +a
RETENTION_DAYS=3650 ~/bin/expat8-backup.sh
```

## Diễn tập restore (mỗi tháng)

Backup chưa restore thử thì chưa chắc dùng được. Restore vào **database tạm** trên cùng server, không động vào DB thật:

```bash
cd ~/deployment/worker-z440
DUMP=$(ls -t ~/backups/expat8/expat8-db-*.dump | head -1)
docker compose exec -T postgres createdb -U <user> expat8_restore_check
docker compose exec -T postgres pg_restore -U <user> -d expat8_restore_check --no-owner < "$DUMP"
docker compose exec -T postgres psql -U <user> -d expat8_restore_check -Atc \
  "select (select count(*) from users) users,
          (select count(*) from study_events) study_events,
          (select max(version) from schema_migrations) last_migration"
docker compose exec -T postgres dropdb -U <user> expat8_restore_check
```

Kết quả đúng: số liệu gần với DB thật, `last_migration` là migration mới nhất đã deploy. Ghi ngày diễn tập vào nhật ký vận hành.

## Khôi phục production

Chỉ làm khi dữ liệu **hỏng hoặc mất**. Image lỗi thì rollback image theo [deploy.md](deploy.md#6-rollback), không restore.

Hệ quả cần chấp nhận: mọi thứ ghi sau thời điểm dump sẽ mất. App sẽ gửi lại những sự kiện **còn trong hàng đợi** trên máy; sự kiện đã đồng bộ xong trước sự cố thì không gửi lại. Tài khoản đăng ký sau thời điểm dump sẽ phải đăng ký lại.

1. Dừng ghi:
   ```bash
   cd ~/deployment/worker-z440
   docker compose stop expat8-backend expat8-worker expat8-dashboard
   ```
2. Dump trạng thái hiện tại (kể cả khi hỏng) để còn điều tra: `RETENTION_DAYS=3650 ~/bin/expat8-backup.sh` (nếu script báo dump hỏng, chạy `pg_dump` tay ra file khác).
3. Khôi phục vào DB mới, **giữ DB cũ** để lùi lại nếu cần:
   ```bash
   docker compose exec -T postgres createdb -U <user> <expat8_db>_restored
   docker compose exec -T postgres pg_restore -U <user> -d <expat8_db>_restored --no-owner < ~/backups/expat8/expat8-db-<stamp>.dump
   ```
4. Trỏ Expat8 sang DB mới: đổi tên DB trong `DATABASE_URL` (và `EXPAT8_DASHBOARD_DATABASE_URL`) ở `.env`. Nếu pgbouncer khai báo DB theo tên, thêm mục cho DB mới trong cấu hình pgbouncer (`/home/beou/datadir/pgbouncer`); pgbouncer dùng chung với dự án khác nên **chỉ reload, không restart**: `docker compose exec pgbouncer kill -HUP 1` (hoặc lệnh `RELOAD;` trong console admin của pgbouncer). Kiểm tra trước bằng `docker compose exec pgbouncer cat /etc/pgbouncer/pgbouncer.ini`.
5. Chạy migrate (bản dump có thể cũ hơn code) theo [deploy.md](deploy.md#3-migrate-database), rồi bật lại:
   ```bash
   docker compose up -d expat8-backend expat8-worker expat8-dashboard
   node scripts/ops-check.mjs
   ```
6. Khôi phục APK nếu mất volume:
   ```bash
   docker run --rm -v worker-z440_expat8-releases:/data -v ~/backups/expat8:/backup alpine \
     tar xzf /backup/expat8-releases-<stamp>.tar.gz -C /data
   ```
   Hoặc upload lại bản mới nhất theo [mobile-release.md](mobile-release.md#4-đưa-apk-lên-backend-cập-nhật-trong-app).
7. Ghi lại sự cố: thời điểm hỏng, bản dump đã dùng, khoảng dữ liệu bị mất. Giữ DB cũ ít nhất 7 ngày rồi mới `dropdb`.

## Mục tiêu

| Chỉ số | Mục tiêu hiện tại |
|---|---|
| RPO (dữ liệu tối đa có thể mất) | 24 giờ (backup hằng đêm); dữ liệu còn trong hàng đợi trên máy được gửi lại |
| RTO (thời gian khôi phục) | 1 giờ |
| Giữ bản backup | 14 ngày trên máy, lâu hơn ở nơi lưu ngoài |

Muốn RPO nhỏ hơn thì cần WAL archiving/PITR cho Postgres. Postgres này dùng chung với dự án khác, nên phải bàn chung trước khi làm.

> Đã kiểm chứng (2026-09-29) trên PostgreSQL 16 tạm: `backup.sh` tạo dump và tar APK; DB không tồn tại thì exit 1 và không để lại file dở; bản cũ quá hạn bị xoá; dump restore vào DB mới đủ bảng và đủ 30 migration.
