# Giám sát

## Kiểm tra tự động (cron 5 phút)

`scripts/ops-check.mjs` kiểm tra lần lượt:

| Kiểm tra | Lỗi khi |
|---|---|
| `health` | `GET /health` khác 200 (tiến trình API chết hoặc proxy hỏng) |
| `ready (database)` | `GET /health/ready` khác 200 hoặc `db` khác `ok` (mất kết nối DB/pgbouncer) |
| `content pipeline` | Có mục `failed_count > 0`, hàng chờ vượt `OPS_PENDING_THRESHOLD` (mặc định 20), hoặc có việc chờ mà không xử lý gì trong `OPS_STALE_MINUTES` (mặc định 60) |
| `in-app update matches GitHub release` | Bản trên backend (`/v1/releases/latest`) khác bản GitHub Release mới nhất |

Exit 0 là ổn, 1 là có lỗi. Mỗi kiểm tra in một dòng `OK`/`FAIL`. Chạy từ một máy **ngoài** Z440 với URL public thì bắt được cả lỗi reverse proxy:

```cron
*/5 * * * * set -a; . $HOME/.config/expat8/ops.env; set +a; cd <repo> && node scripts/ops-check.mjs > /tmp/expat8-ops-check.txt 2>&1 || <lệnh gửi cảnh báo> < /tmp/expat8-ops-check.txt
```

`<lệnh gửi cảnh báo>` là kênh nhóm đang dùng (Telegram bot, email, webhook…). Để tránh báo liên tục, chỉ gửi khi trạng thái đổi, hoặc dùng dịch vụ uptime (Uptime Kuma, Healthchecks.io) trỏ vào `https://expat8.x51.vn/health`.

`failed_count` là tổng số mục đang ở trạng thái lỗi nên sẽ báo mãi cho đến khi xử lý xong ([troubleshooting.md](troubleshooting.md#5-bài-viết--passage-kẹt-hoặc-lỗi-xử-lý)). Đó là chủ ý: lỗi xử lý nội dung cần người xem.

## Theo dõi hằng ngày (5 phút)

1. `node scripts/ops-check.mjs` toàn `OK`.
2. Dashboard `/ops`: số vòng luyện nói hoàn thành trong tuần, cảnh báo nội dung cũ quá 7 ngày.
3. Dashboard `/system/pipeline`: hàng đợi bài viết/passage/shadowing.
4. Lỗi trong log 24h qua (lệnh ở dưới): không có lỗi mới lạ.
5. `docker compose ps`: `expat8-backend` `healthy`, worker và dashboard `Up`, không restart liên tục.

## Đọc log

Backend và worker ghi mỗi sự kiện thành **một dòng JSON** trên stdout: `timestamp`, `level` (`debug`/`info`/`warn`/`error`), `event`, `component` và các trường riêng. Mỗi request có `request_id` (trả về trong header `x-request-id`), nên có thể lần theo cả vòng đời một request. Trường nhạy cảm bị thay bằng `[REDACTED]` (`LOG_REDACTION_ENABLED=true`).

Dùng `docker logs <container>` (không có tiền tố tên service) và `jq`:

```bash
# lỗi trong 1 giờ qua
docker logs --since 1h expat8-backend 2>&1 | jq -Rc 'fromjson? | select(.level=="error")'

# đếm lỗi theo loại trong 24h
docker logs --since 24h expat8-backend 2>&1 | jq -Rr 'fromjson? | select(.level=="error" or .level=="warn") | .event' | sort | uniq -c | sort -rn

# request 5xx và request chậm (> 2 giây)
docker logs --since 1h expat8-backend 2>&1 | jq -Rc 'fromjson? | select(.event=="request_completed" and (.status_code>=500 or .elapsed_ms>2000)) | {timestamp,path,status_code,elapsed_ms,request_id}'

# lần theo một request
docker logs --since 24h expat8-backend 2>&1 | grep '<request_id>'

# worker
docker logs --since 1h expat8-worker 2>&1 | jq -Rc 'fromjson? | select(.level!="info" and .level!="debug")'
```

### Sự kiện cần chú ý

| `event` | Mức | Ý nghĩa và việc cần làm |
|---|---|---|
| `request_failed` | error | Lỗi chưa xử lý trong API (có `status_code`, `path`, `category`). Nhiều request lỗi cùng một path thì mở issue |
| `replay_protection_unavailable` | warn | Không ghi được nonce vào DB nên API trả 503 cho mọi request có ký. Kiểm tra DB ([troubleshooting.md](troubleshooting.md#4-healthready-503--api-trả-503)) |
| `db_transaction_failed` | error | Giao dịch DB lỗi. Xem thông báo lỗi Postgres kèm theo |
| `route_not_found` | warn | App gọi endpoint không có; nhiều lần thì backend cũ hơn app ([troubleshooting.md](troubleshooting.md#9-app-mới-nhưng-backend-cũ--dữ-liệu-bị-bỏ)) |
| `db.migration.failed` | error | Migrate lỗi, dừng deploy ([troubleshooting.md](troubleshooting.md#7-migrate-lỗi-hoặc-treo)) |
| `article_worker_tick_failed`, `passage_*_worker_tick_failed`, `submitted_word_worker_tick_failed` | error | Một vòng worker lỗi; lặp lại liên tục là worker hỏng |
| `article_processing_job_failed`, `passage_segmentation_failed`, `passage_enrichment_failed`, `submitted_word_job_failed` | error | Một mục xử lý lỗi (thường do LLM) |
| `litellm_chat_completion_http_error`, `litellm_chat_completion_fetch_error`, `litellm_request_failed` | warn/error | LiteLLM lỗi hoặc không kết nối được; học thẻ không bị ảnh hưởng |
| `scheduler_run_failed`, `scheduler_generation_failed` | error | Không sinh thêm được từ vựng vào kho |
| `article_worker_drain_timeout` | warn | Worker bị dừng khi đang xử lý dở; job được làm lại ở lần sau |
| `release_store_apk_missing`, `release_store_metadata_invalid` | warn | Volume `expat8-releases` thiếu file; upload lại APK |
| `article_processing_backlog` | info | Số job bài viết đang chờ (ghi mỗi tick) |

## Log từ điện thoại người dùng

Khi người dùng báo lỗi: nhờ họ mở **Menu → Tools & settings → Logs** rồi bấm nút **Send logs to server**. Log được nén và lưu ở volume `expat8-log-archives` (giữ 3 ngày, tổng tối đa 100 MB). Xem ở dashboard `/ops/logs` hoặc bằng `node scripts/admin-request.mjs GET /v1/admin/log-archives`. Log app chứa các sự kiện đồng bộ (`sync`), lỗi mạng và lỗi API kèm mã HTTP.

## Postgres

Postgres ghi truy vấn chậm hơn 1 giây (`log_min_duration_statement=1000`), lock chờ và DDL vào `/home/beou/datadir/logs` trên Z440. Kiểm tra nhanh:

```bash
docker compose exec -T postgres psql -U <user> -d <expat8_db> -c "
select count(*) filter (where state='active') active, count(*) total
from pg_stat_activity where datname = current_database();"
docker compose exec -T postgres psql -U <user> -d <expat8_db> -c "
select relname, pg_size_pretty(pg_total_relation_size(relid)) size
from pg_statio_user_tables order by pg_total_relation_size(relid) desc limit 10;"
```

`max_connections` của Postgres là 100 và dùng chung. Mỗi tiến trình Expat8 mở tối đa `DB_POOL_MAX` (mặc định 10) kết nối tới pgbouncer.

## Ngưỡng tham khảo

| Chỉ số | Bình thường | Cần xem |
|---|---|---|
| `/health/ready` | 200 | 503 dù chỉ một lần |
| Tỉ lệ request 5xx | ~0 | > 1% trong 15 phút |
| `elapsed_ms` của `POST /v1/learning/cards` | < 300 ms | > 1 s kéo dài |
| Hàng chờ bài viết/passage | 0–5 | > 20, hoặc không giảm trong 1 giờ |
| `failed_count` (content pipeline) | 0 | > 0 |
| Dung lượng đĩa Z440 | < 70% | > 85% ([maintenance.md](maintenance.md#dung-lượng-đĩa)) |
| Backup mới nhất | < 24 h | > 26 h |

> Đã kiểm chứng (2026-09-29): `ops-check.mjs` chạy với backend + PostgreSQL thật: báo `FAIL` khi backend chưa có APK bản mới, `OK` sau khi upload, `FAIL` với exit 1 khi backend không truy cập được.
