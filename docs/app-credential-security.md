# App Credential Security

Tài liệu này mô tả cơ chế đơn giản để bảo vệ API public bằng `appId` và
`secret`, đồng thời giảm rủi ro request giả mạo, replay, brute force và DDOS.
Đây là tài liệu thiết kế; chưa phải triển khai code.

## Mục tiêu

- Mọi request gọi API nghiệp vụ phải có credential hợp lệ trước khi đi vào
  route handler, database hoặc LiteLLM.
- Request thiếu, sai định dạng, sai chữ ký, hết hạn hoặc replay đều trả `400
  Bad Request`.
- Response lỗi không tiết lộ credential nào tồn tại, chữ ký sai ở đâu, hay
  server kỳ vọng giá trị gì.
- Secret không được commit vào repo, không log ra console, không gửi ngược về
  client.
- Cơ chế đủ đơn giản cho backend ExpressJS, nhưng không chặn việc thêm user
  auth, device attestation hoặc WAF sau này.

## Giới hạn bảo mật cần hiểu rõ

`appId` là public identifier. Với mobile app hoặc web app public, nếu `secret`
được nhúng trực tiếp trong app bundle thì attacker có thể trích xuất nó. Vì vậy
HMAC app secret chỉ nên xem là lớp bảo vệ đầu vào, không phải user authentication
và không phải bằng chứng tuyệt đối rằng request đến từ app thật.

Mô hình nên là nhiều lớp:

```text
Internet
   |
   v
┌──────────────────────────────┐
│ Edge/WAF/IP rate limit        │  chặn volumetric DDOS trước app
└──────────────┬───────────────┘
               v
┌──────────────────────────────┐
│ Express early middleware      │  header, body size, app signature
└──────────────┬───────────────┘
               v
┌──────────────────────────────┐
│ Express routers               │  /v1/words, /v1/study-events
└──────────────┬───────────────┘
               v
┌──────────────────────────────┐
│ Store / LiteLLM               │
└──────────────────────────────┘
```

## Endpoint scope

- `GET /health`: nên giữ unauthenticated nếu cần cho load balancer/container
  health check. Nếu health endpoint public trên Internet, chỉ trả `{ "ok": true
  }` và không lộ cấu hình.
- Tất cả endpoint dưới `/v1/*`: bắt buộc có app credential hợp lệ.
- Endpoint quản trị credential sau này, nếu có, không dùng chung cơ chế public
  app secret; phải dùng admin auth riêng.

## ExpressJS placement

Backend nên dùng ExpressJS làm HTTP framework cho API public. App credential
guard phải là middleware ở lớp ngoài cùng của `/v1/*`, trước router nghiệp vụ,
trước database access và trước LiteLLM.

Thứ tự middleware đề xuất:

```text
express app
  |
  +-- GET /health                         no app credential
  |
  +-- /v1/*
        |
        +-- coarseIpRateLimit             cheap reject trước body/HMAC
        |
        +-- captureRawBodyWithLimit       giữ raw bytes để hash/signature
        |
        +-- appCredentialGuard            appId, timestamp, nonce, HMAC
        |
        +-- expressJsonFromCapturedBody   parse JSON sau khi credential hợp lệ
        |
        +-- v1Router                      words/recent/sync handlers
```

Không đặt `express.json()` global trước credential guard cho `/v1/*`, vì khi đó
backend có thể đã đọc và parse body của request không hợp lệ. Với endpoint cần
body JSON, middleware nên capture raw body có giới hạn kích thước, verify
signature trên raw bytes, rồi mới parse JSON.

Với GET request, middleware vẫn kiểm tra credential nhưng body limit nên là `0`
bytes.

## Request headers

Client gửi các header sau cho mọi request `/v1/*`:

```http
X-Expat8-App-Id: app_mobile_prod
X-Expat8-Timestamp: 2026-05-04T10:30:00.000Z
X-Expat8-Nonce: 4b4194f3f1df4a7b9f0f77e1c13e4581
X-Expat8-Content-SHA256: base64url(sha256(raw_request_body))
X-Expat8-Signature: v1=base64url(hmac_sha256(secret, canonical_request))
```

Với request không có body, `X-Expat8-Content-SHA256` là hash của empty bytes.

## Canonical request

Signature phải được tính từ chuỗi canonical ổn định:

```text
v1
METHOD
PATH_WITH_SORTED_QUERY
TIMESTAMP
NONCE
CONTENT_SHA256
```

Ví dụ:

```text
v1
POST
/v1/learning/cards
2026-05-04T10:30:00.000Z
4b4194f3f1df4a7b9f0f77e1c13e4581
mz4oQYJ6Xv6pY8...
```

Quy tắc:

- `METHOD` viết hoa.
- Path giữ nguyên dạng URL path.
- Query parameter được sort theo key rồi value trước khi ký.
- Không ký host header, vì host có thể thay đổi qua proxy.
- Không ký header không ổn định như `user-agent`.
- Timestamp dùng UTC ISO-8601.

## Luồng xác thực request

```text
request
  |
  v
┌──────────────────────────────┐
│ 1. Express path scope         │
└──────────────┬───────────────┘
               v
┌──────────────────────────────┐
│ 2. IP coarse rate limit       │  trước khi đọc body/HMAC
└──────────────┬───────────────┘
               v
┌──────────────────────────────┐
│ 3. Validate required headers  │
└──────────────┬───────────────┘
               v
┌──────────────────────────────┐
│ 4. Enforce body size limit    │
└──────────────┬───────────────┘
               v
┌──────────────────────────────┐
│ 5. Capture raw body + hash    │
└──────────────┬───────────────┘
               v
┌──────────────────────────────┐
│ 6. Lookup active appId        │
└──────────────┬───────────────┘
               v
┌──────────────────────────────┐
│ 7. Check timestamp window     │
└──────────────┬───────────────┘
               v
┌──────────────────────────────┐
│ 8. Check nonce replay cache   │
└──────────────┬───────────────┘
               v
┌──────────────────────────────┐
│ 9. HMAC + timing-safe compare │
└──────────────┬───────────────┘
               v
┌──────────────────────────────┐
│ 10. Express route handler     │
└──────────────────────────────┘
```

Bất kỳ bước nào fail đều trả:

```json
{ "error": "bad_request" }
```

Status code: `400`.

Không phân biệt `unknown_app_id`, `bad_signature`, `expired_timestamp`, hay
`replayed_nonce` trong response public.

## Credential storage

Để đơn giản cho giai đoạn đầu, backend đọc credential từ runtime environment:

```env
APP_CREDENTIALS_JSON=[
  {
    "appId": "app_mobile_prod",
    "secret": "base64url-random-32-bytes-or-more",
    "status": "active"
  },
  {
    "appId": "app_mobile_prod_next",
    "secret": "base64url-random-32-bytes-or-more",
    "status": "active"
  }
]
```

Implementation hiện tại cũng đọc các biến:

- `APP_CREDENTIAL_TIMESTAMP_SKEW_SECONDS`, default `300`.
- `APP_CREDENTIAL_NONCE_TTL_SECONDS`, default `300`.
- `APP_CREDENTIAL_GET_BODY_LIMIT_BYTES`, default `0`.
- `APP_CREDENTIAL_POST_BODY_LIMIT_BYTES`, default `262144`.

Nguyên tắc:

- Giá trị thật nằm trong secret manager hoặc `.env` không versioned.
- `.env.example` chỉ có placeholder, không có secret thật.
- Secret sinh bằng CSPRNG, tối thiểu 32 bytes entropy.
- App credential được load khi process start; lỗi parse credential phải làm
  backend fail fast ở môi trường production.
- Không log secret, signature, raw authorization header hoặc raw body nếu body
  có thể chứa dữ liệu nhạy cảm.

Khi cần quản trị động hoặc nhiều client, chuyển sang bảng database:

```sql
app_credentials(
  app_id text primary key,
  secret_hash text not null,
  status text not null,
  created_at text not null,
  rotated_at text,
  revoked_at text
)
```

Nếu dùng database, chỉ lưu hash của secret bằng keyed hash/pepper ở server hoặc
KMS-backed secret reference. Tuy nhiên để verify HMAC, backend cần truy cập được
secret thật hoặc secret material qua KMS/secret manager.

## Rotation và revoke

Rotation nên cho phép overlap ngắn:

```text
old secret active ────────┐
                          ├── overlap 24h ── revoke old
new secret active ────────┘
```

Quy trình:

1. Tạo app credential mới.
2. Deploy app/client dùng credential mới.
3. Giữ credential cũ active trong cửa sổ tương thích ngắn.
4. Sau khi traffic credential cũ về gần 0, chuyển credential cũ sang revoked.
5. Alert nếu credential revoked vẫn còn traffic đáng kể.

## Replay protection

Backend cần lưu nonce đã dùng trong TTL ngắn, ví dụ 5 phút:

```text
key = appId + ":" + nonce
ttl = 5 minutes
```

- Nếu key đã tồn tại: trả `400`.
- Nếu timestamp lệch quá cửa sổ cho phép: trả `400`.
- Với một process: implementation hiện tại dùng in-memory TTL cache.
- Với nhiều instance: cần thay bằng Redis hoặc cache tập trung trước khi scale
  ngang.
- Nonce phải đủ dài và random, khuyến nghị 128-bit trở lên.

## Rate limit và DDOS posture

Các lớp đề xuất:

| Lớp | Key | Mục đích |
| --- | --- | --- |
| Edge/WAF | IP / ASN / country / path | Chặn volumetric DDOS trước backend |
| Backend coarse limit | IP | Giảm CPU trước khi HMAC |
| Invalid credential limit | IP + appId candidate | Làm chậm brute force |
| Valid app limit | appId | Bảo vệ quota API theo app |
| Device/user limit sau này | device_id / user_id | Chặn abuse bên trong credential hợp lệ |

Backend không nên tự gánh toàn bộ DDOS. Nếu public Internet thật, nên đặt sau
Cloudflare, nginx rate limit, load balancer rule, hoặc API gateway.

Các default hợp lý cho backend guard:

- Body tối đa cho `/v1/study-events/sync`: ví dụ 256 KB.
- Body tối đa cho GET: 0 bytes.
- Timestamp skew: 5 phút.
- Nonce TTL: 5 phút.
- Invalid request burst per IP: thấp hơn valid request burst.
- HMAC computation chỉ chạy sau khi header/body size/timestamp format qua được
  kiểm tra cơ bản.

## Attack scenarios

| Tấn công | Cách giảm thiểu |
| --- | --- |
| Missing credential | Reject trước route handler, trả `400` |
| Random appId brute force | Generic `400`, IP invalid-rate-limit, không lộ appId tồn tại |
| Signature brute force | Secret entropy cao, HMAC SHA-256, timing-safe compare |
| Replay request hợp lệ | Timestamp window + nonce TTL cache |
| Body tampering | Signature bao gồm SHA-256 của raw body |
| Query tampering | Signature bao gồm path và sorted query |
| Oversized body | Body size limit trước JSON parse |
| JSON parse bomb | Size limit + parse sau credential guard |
| Credential leaked | Rotation/revoke, telemetry theo appId, phát hiện traffic bất thường |
| Mobile secret extraction | Xem HMAC là lớp cơ bản; bổ sung Play Integrity/App Attest sau |
| Volumetric DDOS | Edge/WAF/rate limit ngoài Express process |

## Logging và observability

Nên log structured event tối thiểu:

```json
{
  "event": "app_credential_rejected",
  "reason_class": "invalid_request",
  "path": "/v1/learning/cards",
  "method": "POST",
  "app_id_present": true,
  "ip_hash": "hashed-ip",
  "timestamp": "2026-05-04T10:30:01.000Z"
}
```

Không log:

- Secret.
- Signature đầy đủ.
- Nonce đầy đủ nếu không cần thiết.
- Raw request body.
- Dữ liệu học có thể nhận diện người dùng sau này.

Metrics nên có:

- `app_credential.accepted.count`
- `app_credential.rejected.count`
- `app_credential.replayed_nonce.count`
- `app_credential.invalid_signature.count`
- `rate_limit.rejected.count`
- Latency của credential guard.

## Tác động lên client

Mobile/backend API client cần có bước ký request:

```text
raw body -> sha256 -> canonical request -> hmac(secret) -> headers -> fetch
```

Với public mobile app, không nên hard-code một secret production duy nhất mãi
mãi. Nên chuẩn bị:

- Secret theo environment: dev, staging, prod.
- Rotation định kỳ.
- Remote config hoặc app update bắt buộc khi revoke credential cũ.
- Sau này thêm device attestation để đổi attestation hợp lệ lấy short-lived app
  token, thay vì ký mọi request bằng secret nhúng trong app.

## Quan hệ với user auth tương lai

App credential trả lời câu hỏi: "request này có format và chữ ký của một app
được cấp phép không?"

User auth trả lời câu hỏi: "người dùng này là ai và được phép làm gì?"

Hai lớp nên độc lập:

```text
request
  |
  +--> app credential guard  -> app hợp lệ?
  |
  +--> user auth guard       -> user/device hợp lệ?
  |
  +--> business handler
```

Khi thêm login, vẫn giữ app credential ở lớp ngoài để giảm request rác trước khi
đụng user/session store.

## Quyết định đề xuất cho Expat8

Với codebase hiện tại, lựa chọn cân bằng là:

- Bảo vệ `/v1/*` bằng HMAC app credential.
- Giữ `/health` không auth nhưng tối giản response.
- Đọc credential từ `APP_CREDENTIALS_JSON` trong environment ở giai đoạn đầu.
- Dùng ExpressJS cho backend API public.
- Mount middleware credential trên `/v1/*` trước `v1Router`.
- Không dùng `express.json()` global trước credential guard; chỉ parse JSON sau
  khi raw body đã được giới hạn kích thước, hash và verify HMAC.
- Dùng raw body hash để tránh request body bị thay đổi sau khi ký.
- Trả cùng một lỗi `400 { "error": "bad_request" }` cho mọi credential failure.
- Thêm body size limit và nonce TTL cache trước khi mở rộng API public.
- Đặt backend sau edge rate limit khi public Internet.

## Câu hỏi còn mở

- Public app đầu tiên là mobile-only, web-only, hay cả hai?
- Backend sẽ chạy một instance hay nhiều instance? Câu này quyết định nonce cache
  dùng memory hay Redis.
- Hạ tầng public có Cloudflare/nginx/API gateway không?
- Có yêu cầu cho partner app bên thứ ba không, hay chỉ app Expat8 chính thức?
- Có chấp nhận tích hợp Play Integrity/App Attest ở phase sau không?
