# Mobile System Logging

## Muc tieu
Tai lieu nay mo ta cach dung logging subsystem tren mobile app de debug va trace loi tren may that ma khong can ket noi emulator.

## Cau hinh
App ho tro cac bien `--dart-define` sau:
- `APP_LOG_LEVEL`: muc log toi thieu (`debug`, `info`, `warning`, `error`)
- `APP_LOG_MAX_ENTRIES`: so ban ghi toi da giu lai trong local store

Luu y build:
- Moi khi thay `BACKEND_BASE_URL`, `APP_CREDENTIAL_APP_ID`, `APP_CREDENTIAL_SECRET`, `APP_LOG_LEVEL`, hoac `APP_LOG_MAX_ENTRIES`, phai rebuild APK/AAB de binary lay cau hinh moi.
- Gia tri that phai duoc cung cap tu env file local hoac secret store, khong hardcode trong file commit len GitHub.

Retention theo tuoi duoc co dinh o 60 phut. Normal build khong ho tro cau hinh
giu log lau hon moc nay.

Gia tri mac dinh:
- `APP_LOG_LEVEL=info`
- `APP_LOG_MAX_ENTRIES=5000`
- Log age retention: 60 phut

Vi du chay debug:
```bash
flutter run -d emulator-5554 \
  --dart-define=BACKEND_BASE_URL=<YOUR_BACKEND_URL> \
  --dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app \
  --dart-define=APP_CREDENTIAL_SECRET=<YOUR_APP_SECRET> \
  --dart-define=APP_LOG_LEVEL=debug
```

## Cac nguon log duoc ghi
- API lifecycle: request/response/error cho `learning/cards`, `proficiency`, `study-events`, `study-events/sync`
- Session lifecycle: load initial, new word request, review request, rating submit, level change
- Sync lifecycle: batch start, retry scheduling, sync worker run
- Local DB lifecycle: upsert word, retry scheduling, log persistence
- Auth lifecycle: register/sign-in/sign-out success/failure

## Mo man hinh log trong app
1. Mo drawer tu man hinh hoc tu vung
2. Chon `Logs`
3. Chon filter:
- Minimum Level
- Category
4. Bam `Refresh` de tai lai danh sach

## Export log
1. Trong man hinh `System Logs`, bam icon `Export logs`
2. App tao file text `.txt` da sanitize trong temp storage
3. Native share sheet mo ra de gui file qua app co san tren thiet bi, vi du Zalo,
   Telegram, email, Messages, hoac cloud drive
4. Snackbar hien trang thai no-log, share thanh cong, bi dong, hoac unavailable

Ghi chu:
- Neu khong co log nao khop filter hien tai, app khong mo empty share sheet.
- Neu chay tren web test mode, export tra ve payload in-memory thay vi file path.

## Bao mat va redaction
Truoc khi persist hoac export, app redact cac truong nhay cam:
- `authorization`, `token`, `session_token`
- `password`
- `app_secret`, `secret`
- Chuoi bearer token trong message

Tat ca gia tri nhay cam duoc thay bang `[REDACTED]`.

## Checklist debug tren may that
1. Tai hien loi tren may that
2. Mo `Logs` va chon `warning` hoac `error`
3. Kiem tra `trace_id`, `event`, `category` theo timeline
4. Export file text va gui cho team ky thuat qua share sheet
5. Neu can trace sau hon, chay lai voi `APP_LOG_LEVEL=debug`

## Luu y van hanh
- Logging chi giu log trong 60 phut va gioi han them theo so luong ban ghi de
  tranh phinh bo nho
- Neu gap van de hieu nang, giam level ve `warning` trong production
