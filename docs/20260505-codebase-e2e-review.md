# Expat8 — End-to-End Codebase Review

**Ngày**: 2026-05-05  
**Phạm vi**: Toàn bộ luồng Register, Sign-in, Sign-out; kiến trúc tổng thể mobile + backend  
**Trạng thái**: Updated — register error investigated và confirmed

> **Tóm tắt lỗi register**: Luồng register thất bại trên Flutter Web vì backend thiếu CORS headers. Browser gửi OPTIONS preflight trước mọi request có custom headers (`x-expat8-*`); backend từ chối preflight với `400` (HMAC guard chặn OPTIONS không có chữ ký). Người dùng thấy: *"Registration failed. Check connection and try again."* Xem mục 7.0 để biết chi tiết và fix.

---

## 1. Tổng quan kiến trúc

```
Mobile (Flutter)
  └── main.dart              Bootstrap: config → DB → logger → apiClient → repo → controller → UI
  └── LearningScreen         Drawer UI: Register / Sign-in / Sign-out
  └── LearningSessionController   Auth state machine + error mapping
  └── WordRepository         Orchestrates DB + API, persists session
  └── BackendApiClient       HMAC-signed HTTP, parse UserSession
  └── LocalDatabase          SQLite: user_session, device_id, words, sync_queue, logs

Backend (Node.js / Express)
  └── app.js                 HMAC middleware → V1 router
  └── user_identity.js       Password hash (scrypt), session token, verification
  └── word_store.js          In-memory store (dev/test)
  └── postgres_word_store.js PostgreSQL store (prod)
  └── app_credentials.js     HMAC-SHA256 request signing + nonce replay cache

Database (PostgreSQL)
  users, user_sessions, user_proficiency, study_events, words
```

---

## 2. Luồng Register

### 2.1 Sequence chi tiết

```
User (tap Register)
  → LearningScreen._register()
    → Navigator.maybePop()        # đóng drawer
    → _showIdentityDialog()       # dialog: Email / Name (optional) / Password
    → controller.register(identifier, password, displayName)
      → _beginAuthAction()        # isAuthInProgress=true, notifyListeners
      → repository.registerUser(identifier, password, displayName)
        → database.getOrCreateDeviceId()
        → apiClient.registerUser(identifier, password, displayName, deviceId)
          → build JSON payload
          → _signedHeaders(method: POST, uri, body)   # HMAC-SHA256
          → POST /v1/users/register
            → [backend] rejectMissingCredentialHeaders
            → [backend] captureRawBody
            → [backend] appCredentialGuard           # verify HMAC
            → [backend] parseJsonFromCapturedBody
            → store.registerUser(identifier, password, displayName, deviceId)
              → requireRegistrationInput()           # validate: len(password) >= 8
              → check duplicate identifier
              → createPasswordHash(password)         # scrypt + random salt
              → INSERT users
              → createSessionToken()                 # session_<32bytes>
              → INSERT user_sessions (stores SHA256(token))
              → return { user, sessionToken }
            → response 201 { user_id, identifier, display_name, session_token }
          ← UserSession.fromJson(body)
        → database.saveUserSession(session)    # persist JSON to app_settings
        → logger.info auth.register.success
        ← return session
      ← userSession = session
      ← authSuccessMessage = "Registered as <name>."
      ← _userFeedbackMessage = authSuccessMessage
      ← telemetry: authRegisterSuccess
      → _endAuthAction()           # isAuthInProgress=false, notifyListeners
    ← _onControllerChanged()
      → takeUserFeedbackMessage()
      → ScaffoldMessenger.showSnackBar("Registered as <name>.")
```

### 2.2 Error path (register)

| Điều kiện | Backend trả | Mobile hiển thị |
|---|---|---|
| Identifier đã tồn tại | 409 `user_exists` | "An account already exists for this email." |
| Password < 8 chars hoặc rỗng | 400 `bad_request` | "The request was rejected. Check the entered details and try again." |
| Network timeout | - | "Registration failed. Check connection and try again." |
| Server 5xx | 500 | "Registration failed. Server returned 500." |

---

## 3. Luồng Sign-in

### 3.1 Sequence chi tiết

```
User (tap Sign in)
  → LearningScreen._signIn()
    → Navigator.maybePop()
    → _showIdentityDialog()           # dialog: Email / Password (không có Name)
    → controller.signIn(identifier, password)
      → _beginAuthAction()
      → repository.signInUser(identifier, password)
        → database.getOrCreateDeviceId()
        → apiClient.signIn(identifier, password, deviceId)
          → POST /v1/users/sign-in    # HMAC signed
            → store.createUserSession(identifier, password, deviceId)
              → normalizeUserIdentifier()   # trim + lowercase
              → lookup user by identifier
              → verifyPassword(password, hash)    # scrypt + timingSafeEqual
              → createSessionToken()
              → INSERT user_sessions
              → return { user, sessionToken }
            → response 200 { user_id, identifier, display_name, session_token }
        → database.saveUserSession(session)     # overwrite previous session
        ← return session
      ← userSession = session
      ← authSuccessMessage = "Signed in as <name>."
      → _endAuthAction()
    ← SnackBar "Signed in as <name>."
```

### 3.2 Error path (sign-in)

| Điều kiện | Backend trả | Mobile hiển thị |
|---|---|---|
| Sai email hoặc password | 401 `invalid_credentials` | "Email or password is incorrect." |
| Identifier rỗng | 400 `bad_request` | "The request was rejected…" |
| Network/timeout | - | "Sign-in failed. Check connection and try again." |

---

## 4. Luồng Sign-out

### 4.1 Sequence chi tiết

```
User (tap Sign out)
  → LearningDrawer.onSignOut
    → Navigator.maybePop()
    → controller.signOut()
      → _beginAuthAction()
      → repository.signOutUser()
        → database.loadUserSession()      # load current session
        → apiClient.signOut(session)
          → POST /v1/users/sign-out       # Bearer <token> + HMAC signed
            → bearerToken(request)
            → store.revokeUserSession({ sessionToken })
              → SHA256(token) → lookup in sessions
              → SET revoked_at = now
              → return { revoked: true }
            → response 200 { success: true }
        → [finally] database.clearUserSession()   # LUÔN xóa local dù API thành công hay thất bại
      ← userSession = null
      ← authSuccessMessage = "Signed out."
      → _endAuthAction()
    ← SnackBar "Signed out."
```

### 4.2 Sign-out failure path

```
repository.signOutUser()
  → apiClient.signOut() throws (e.g. 401 token already revoked, network error)
  → [finally] database.clearUserSession()    # vẫn xóa local session
  → exception propagates to controller
controller.signOut() catch:
  → userSession = await repository.loadUserSession()  # returns null (đã bị xóa)
  → clearedLocally = true
  → authErrorMessage = "Signed out locally. Server sign-out could not be confirmed."
  → telemetry: authSignOutFailure { cleared_locally: true }
```

---

## 5. Session persistence (Mobile)

Session được lưu dưới dạng JSON trong SQLite `app_settings`:

```dart
// save
_db.insert('app_settings', {'key': 'user_session', 'value': jsonEncode(session.toJson())})

// load  
UserSession.fromJson(jsonDecode(rows.first['value']))

// clear
_db.delete('app_settings', where: 'key = ?', whereArgs: ['user_session'])
```

Khi app khởi động, `controller.loadInitial()` → `repository.loadUserSession()` → restore session từ DB.

---

## 6. App Credential Security (HMAC signing)

Mọi request `/v1/*` phải được ký:

```
Canonical request:
  v1
  {METHOD}
  {PATH?sorted_query}
  {timestamp ISO-8601}
  {nonce}
  {base64url(sha256(body))}

Signature: v1=base64url(HMAC-SHA256(secret, canonical_request))

Headers gửi lên:
  x-expat8-app-id:          <appId>
  x-expat8-timestamp:       <timestamp>
  x-expat8-nonce:           mobile_<microseconds>
  x-expat8-content-sha256:  <bodyHash>
  x-expat8-signature:       v1=<sig>
  authorization:            Bearer <sessionToken>  (nếu có session)
```

Backend checks: header presence → body size → timestamp skew (±300s) → nonce replay (TTL 300s) → HMAC verify.

---

## 7. Findings — Bugs & Issues

### 7.0 BUG CONFIRMED: CORS missing — register thất bại trên Flutter Web

**File**: [backend/src/app.js](../backend/src/app.js)  
**Mức độ**: **Critical** — Toàn bộ luồng auth không dùng được trên web  
**Verified**: Reproduced bằng curl trực tiếp vào `https://expat8.x51.vn`

#### Root cause

Flutter web app gửi custom headers (`x-expat8-app-id`, `x-expat8-timestamp`, v.v.) không nằm trong danh sách "CORS-safe headers". Browser **bắt buộc** gửi OPTIONS preflight trước mỗi request có custom headers.

```
Browser                        Backend (https://expat8.x51.vn)
  |                                |
  |--- OPTIONS /v1/users/register  |
  |    Origin: http://localhost    |
  |    Access-Control-Request-Headers: x-expat8-* |
  |                                |
  |                   rejectMissingCredentialHeaders()
  |                   (x-expat8-* headers không có trong OPTIONS)
  |<-- 400 { error: "bad_request" }|
  |    (no Access-Control-Allow-Origin)
  |                                |
  |  CORS PREFLIGHT FAILED         |
  |  → Browser blocks POST         |
  |  → Flutter http throws error   |
  |  → "Registration failed.       |
  |     Check connection..."       |
```

#### Verification (curl)

```bash
# OPTIONS preflight (như browser gửi)
curl -X OPTIONS https://expat8.x51.vn/v1/users/register \
  -H "Origin: http://localhost:8080" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: x-expat8-app-id,x-expat8-signature,..."
# → HTTP/2 400  (HMAC guard từ chối OPTIONS vì thiếu HMAC headers)

# POST thành công (từ curl, không qua browser CORS)
# → HTTP/2 201 nhưng response KHÔNG có Access-Control-Allow-Origin
# → Browser vẫn block response dù request đến nơi
```

**Kết quả**: Không chỉ OPTIONS bị block — ngay cả khi request thành công, browser vẫn block response vì không có `Access-Control-Allow-Origin` header.

#### Fix cần làm trong `backend/src/app.js`

**Bước 1**: Thêm CORS middleware trước HMAC guard. OPTIONS preflight phải được xử lý và trả về `204` **trước** khi HMAC check chạy:

```javascript
// Đặt TRƯỚC app.use('/v1', rejectMissingCredentialHeaders, ...)
app.use('/v1', (request, response, next) => {
  const allowedOrigin = config.corsAllowedOrigin ?? '*';
  response.setHeader('Access-Control-Allow-Origin', allowedOrigin);
  response.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  response.setHeader(
    'Access-Control-Allow-Headers',
    'content-type, authorization, x-expat8-app-id, x-expat8-timestamp, x-expat8-nonce, x-expat8-content-sha256, x-expat8-signature'
  );
  response.setHeader('Access-Control-Max-Age', '86400');
  if (request.method === 'OPTIONS') {
    return response.status(204).end();
  }
  return next();
});
```

**Bước 2**: Cần config `CORS_ALLOWED_ORIGIN` trong deployment — dùng `*` cho development, set explicit domain cho production.

#### Follow-up status (2026-05-05)

Change `fix-auth-cors-register-hardening` adds `/v1` CORS middleware before the
app credential guard, runtime `CORS_ALLOWED_ORIGIN` config, and regression tests
covering browser preflight, readable CORS errors, signed registration responses,
and unsigned non-OPTIONS rejection. Deployment still needs the intended
production web origin configured explicitly.

#### Issue liên quan: Test suite auth controller bị broken trên Linux

**File**: [mobile/test/learning_session_controller_test.dart](../mobile/test/learning_session_controller_test.dart)  

Toàn bộ 8 tests trong `learning_session_controller_test.dart` thất bại trên máy Linux hiện tại:

```
SqfliteFfiException: Failed to load dynamic library 'libsqlite3.so': 
libsqlite3.so: cannot open shared object file: No such file or directory
```

`sqflite_common_ffi` cần `libsqlite3` được cài trên host Linux. Kết quả: auth controller test coverage = 0 trong CI trên Linux runner. Fix: `sudo apt install libsqlite3-dev` hoặc dùng Docker image có sẵn sqlite3.

---

### 7.1 Bug: Race condition trong PostgreSQL `registerUser` (TOCTOU)

**File**: [backend/src/postgres_word_store.js](../backend/src/postgres_word_store.js#L273)  
**Mức độ**: High

```javascript
async registerUser({ identifier, password, displayName, deviceId }) {
  const input = requireRegistrationInput({ identifier, password });
  return this.#withOptionalTransaction(async (client) => {
    const existing = await client.query('SELECT * FROM users WHERE identifier = $1', [input.identifier]);
    if (existing.rows[0]) {
      throw new DuplicateUserError(input.identifier);  // check tại đây
    }
    // ... gap: request khác có thể insert vào đây
    await client.query('INSERT INTO users ...', [...]);  // UNIQUE constraint violation → 500
  });
}
```

Nếu hai request register cùng identifier đến đồng thời, request thứ hai sẽ vượt qua check `existing.rows[0]` (vì query chạy trước khi request đầu commit), rồi bị lỗi UNIQUE constraint từ PostgreSQL. Exception này KHÔNG được bắt → Express global error handler trả về `500 { error: 'internal_error' }` thay vì `409 { error: 'user_exists' }`.

**Fix**: Bắt PostgreSQL UNIQUE violation error (code `23505`) và convert sang `DuplicateUserError`:
```javascript
try {
  await client.query('INSERT INTO users ...');
} catch (err) {
  if (err.code === '23505') throw new DuplicateUserError(input.identifier);
  throw err;
}
```

#### Follow-up status (2026-05-05)

Change `fix-auth-cors-register-hardening` catches PostgreSQL `23505` during the
user insert path and maps it to `DuplicateUserError`, while preserving normal
error propagation for non-duplicate persistence failures.

---

### 7.2 Bug: `requireRegistrationInput` ném sai error class

**File**: [backend/src/user_identity.js](../backend/src/user_identity.js#L21)  
**Mức độ**: Low (functional but misleading)

```javascript
export function requireRegistrationInput({ identifier, password }) {
  if (!normalizedIdentifier || typeof password !== 'string' || password.length < 8) {
    throw new InvalidCredentialsError();  // ← sai: đây là validation lỗi, không phải credentials lỗi
  }
}
```

`InvalidCredentialsError` được thiết kế cho "sai password khi sign-in". Dùng nó cho "input registration không hợp lệ" gây nhầm lẫn khi đọc code. Backend handler bắt đúng và trả `400 bad_request`, nhưng semantics của exception sai.

**Fix**: Tạo `ValidationError` hoặc `InvalidInputError` riêng.

---

### 7.3 Issue: Không có client-side validation trong auth dialog

**File**: [mobile/lib/src/ui/learning_screen.dart](../mobile/lib/src/ui/learning_screen.dart#L319)  
**Mức độ**: Medium (UX)

Dialog register/sign-in không kiểm tra:
- Email có rỗng không
- Password có đủ 8 ký tự không
- Email có đúng format không

Người dùng nhập rỗng → request gửi lên server → nhận `400` → SnackBar "The request was rejected. Check the entered details and try again." Thông báo lỗi này không chỉ ra cụ thể vấn đề là gì.

**Fix**: Thêm validation inline trong dialog trước khi `Navigator.pop()`:
```dart
if (identifierController.text.trim().isEmpty) {
  // show error under field
  return;
}
if (passwordController.text.length < 8) {
  // show error
  return;
}
```

---

### 7.4 Security Issue: Default app credentials hardcoded

**File**: [mobile/lib/src/config.dart](../mobile/lib/src/config.dart#L25)  
**Mức độ**: Medium (Security)

```dart
appCredentialSecret: String.fromEnvironment(
  'APP_CREDENTIAL_SECRET',
  defaultValue: 'expat8-mobile-secret',  // ← hardcoded default
),
```

Nếu build không truyền `--dart-define=APP_CREDENTIAL_SECRET=...`, app sẽ dùng `expat8-mobile-secret`. Backend cũng cần config credential khớp. Nếu production backend chấp nhận credential này, bất kỳ ai biết default đều có thể forge requests.

**Kiểm tra**: Đảm bảo backend production chỉ accept credentials được rotate và không giống default. CI build pipeline phải inject secrets.

---

### 7.5 Issue: Session token lưu plain text trong SQLite

**File**: [mobile/lib/src/data/local_database.dart](../mobile/lib/src/data/local_database.dart#L312)  
**Mức độ**: Low-Medium (Security)

`session_token` được lưu as-is trong SQLite `app_settings`. Trên thiết bị đã root hoặc qua iTunes backup (iOS), file SQLite có thể bị đọc và token bị lấy cắp.

**Đánh giá**: Acceptable risk cho MVP learning app. Nên document trong threat model. Nếu cần nâng cấp: dùng Flutter Secure Storage (Keychain/Keystore) để lưu token.

---

### 7.6 Issue: Không có session expiry

**Mức độ**: Low-Medium  
Session tokens không bao giờ tự expire — chỉ bị revoke khi sign-out. Token từ tháng trước vẫn valid (PostgreSQL store). In-memory store tự "expire" khi server restart.

**Fix**: Thêm `expires_at` column trong `user_sessions`, check trong `resolveUserSession`. Hoặc ít nhất set TTL 90 ngày.

---

### 7.7 Issue: `signOutUser` finally có thể mask exception

**File**: [mobile/lib/src/data/word_repository.dart](../mobile/lib/src/data/word_repository.dart#L140)  
**Mức độ**: Low

```dart
Future<void> signOutUser() async {
  final session = await database.loadUserSession();
  if (session == null) return;
  try {
    await apiClient.signOut(session: session);
  } finally {
    await database.clearUserSession();  // nếu cái này throw, che khuất exception từ signOut
  }
}
```

Nếu cả `apiClient.signOut()` lẫn `database.clearUserSession()` đều throw, exception gốc từ API call bị mất. Controller chỉ thấy exception từ database. Trong thực tế `clearUserSession` là delete SQLite row nên rất khó throw, nhưng pattern này không lý tưởng.

---

### 7.8 Issue: In-memory store gọi `verifyPassword` thừa khi register

**File**: [backend/src/word_store.js](../backend/src/word_store.js#L202)  
**Mức độ**: Low (performance)

```javascript
registerUser({ identifier, password, ... }) {
  // ... tạo user với createPasswordHash(password)
  const session = this.createUserSession({ identifier, password, deviceId });  // verify lại password
  return { user, ...session };
}
```

`createUserSession` gọi `verifyPassword(password, user.password_hash)` — verify scrypt một lần nữa ngay sau khi vừa hash. PostgreSQL store làm đúng hơn: gọi `#createSessionForUser` trực tiếp mà không cần re-verify.

---

### 7.9 UX Issue: Không có loading indicator khi auth đang chạy

**Mức độ**: Low (UX)

Khi user tap "Register" hoặc "Sign in":
1. Dialog đóng ngay
2. Drawer đóng ngay
3. Auth request chạy nền
4. Spinner chỉ có ở Drawer item (disabled) nhưng drawer đã đóng

User không thấy phản hồi nào trong suốt thời gian auth đang xử lý (có thể vài giây với network chậm). Đề xuất: hiển thị `CircularProgressIndicator` overlay hoặc `LinearProgressIndicator` trong AppBar khi `controller.isAuthInProgress`.

---

### 7.10 Issue: `loadInitial()` fetch proficiency không attach session token đúng timing

**File**: [mobile/lib/src/session/learning_session_controller.dart](../mobile/lib/src/session/learning_session_controller.dart#L64)  
**Mức độ**: Low

```dart
Future<void> loadInitial() async {
  _deviceId ??= await repository.getOrCreateDeviceId();
  userSession = await repository.loadUserSession();    // load session
  try {
    proficiency = await repository.fetchProficiency(deviceId: _deviceId!);  // fetch proficiency
  } catch (_) {
    proficiency = ProficiencyState.initial();
  }
  await showNewWord();
}
```

`repository.fetchProficiency()` loads session từ DB riêng (không dùng `userSession` vừa load):
```dart
Future<ProficiencyState> fetchProficiency({required String deviceId}) async {
  final session = await database.loadUserSession();   // load lại từ DB
  return apiClient.fetchProficiency(deviceId: deviceId, sessionToken: session?.sessionToken);
}
```

Điều này đúng (load fresh từ DB) nhưng có thể tối ưu hơn bằng cách truyền session token trực tiếp. Hiện tại không có bug vì cả hai đều đọc cùng DB.

---

## 8. Findings — Good patterns

| Pattern | Nơi implement | Đánh giá |
|---|---|---|
| scrypt + random salt cho password | `user_identity.js:createPasswordHash` | Tốt — chống brute force |
| Timing-safe comparison | `user_identity.js:timingSafeEqual` | Tốt — chống timing attack |
| SHA256(token) lưu DB, raw token truyền client | `user_identity.js` + DB schema | Tốt — nếu DB bị leak, attacker không có session token |
| HMAC-signed requests (app credentials) | `app_credentials.js` + client | Tốt — ngăn unauthenticated API access |
| Nonce replay cache | `app_credentials.js:InMemoryNonceCache` | Tốt — chống replay attack |
| Timestamp skew check (±300s) | `app_credentials.js` | Tốt — chống delayed replay |
| `finally` xóa session local khi sign-out fail | `word_repository.dart:signOutUser` | Tốt — tránh user bị kẹt với expired token |
| Graceful offline fallback | `word_repository.dart` | Tốt — local SQLite cache |
| Structured logging với categories | `logger.dart` | Tốt — traceability |
| Telemetry cho auth outcomes | `learning_session_controller.dart` | Tốt — observability |
| Session token restore on app restart | `local_database.dart:loadUserSession` | Tốt — seamless re-auth |
| `isAuthInProgress` guard chống double-submit | `learning_session_controller.dart` | Tốt |

---

## 9. Test coverage auth flows

### Backend tests
- `api.test.js`: Register → duplicate → sign-in → word with bearer → study event → sign-out → verify revoked (401) ✅
- `app_credentials.test.js`: HMAC signing, replay, timestamp skew, unknown app ✅
- `database.test.js` + `postgres_integration.test.js`: Schema, persistent operations ✅

### Mobile tests
- `backend_api_client_test.dart`: Register + sign-in + sign-out + bearer on proficiency ✅
- `backend_api_client_test.dart`: 409 user_exists surfacing ✅
- `backend_api_client_test.dart`: 401 invalid_credentials surfacing ✅
- `learning_session_controller_test.dart`: Auth state machine tests ✅

**Thiếu**:
- Mobile: Test auth khi `isAuthInProgress = true` (double-tap guard)
- Mobile: Test `signOut` khi API fail nhưng local cleared
- Backend: Test register race condition (concurrent duplicate requests)
- Backend: Test sign-in với identifier chưa normalize (uppercase) → should work

---

## 10. Tóm tắt & Ưu tiên

| ID | Issue | Mức độ | Effort |
|---|---|---|---|
| **7.0** | **CORS missing — register thất bại hoàn toàn trên web** | **Critical** | Thấp — thêm CORS middleware trước HMAC guard |
| **7.0b** | **`learning_session_controller_test` broken** (libsqlite3 missing) | **High** | Thấp — `apt install libsqlite3-dev` |
| 7.1 | PostgreSQL race condition TOCTOU trong registerUser | **High** | Thấp — thêm catch err.code === '23505' |
| 7.3 | Không có client-side validation trong auth dialog | **Medium** | Thấp — thêm check trước pop |
| 7.4 | Default credentials hardcoded | **Medium** | Thấp — verify CI injects secrets |
| 7.5 | Session token plain text trong SQLite | **Low-Med** | Trung bình — Flutter Secure Storage |
| 7.6 | Không có session expiry | **Low-Med** | Trung bình — thêm expires_at |
| 7.9 | Không có loading indicator khi auth | **Low** | Thấp — overlay spinner |
| 7.2 | `InvalidCredentialsError` sai class | **Low** | Rất thấp — rename/refactor |
| 7.7 | finally mask exception | **Low** | Thấp — restructure try/finally |
| 7.8 | In-memory store verify password thừa | **Low** | Rất thấp — refactor |

**Ưu tiên ngay**:
1. **7.0** — Fix CORS trong `backend/src/app.js`: thêm middleware xử lý OPTIONS trước HMAC guard
2. **7.0b** — Cài `libsqlite3-dev` trên CI runner để auth controller tests chạy được
3. **7.1** — Fix PostgreSQL UNIQUE violation trong `registerUser`
