# Investigation: register/login không phản hồi và swipe không đổi từ

Ngày điều tra: 2026-05-05  
Phạm vi: mobile Flutter, backend identity/feed API, OpenSpec change `add-user-identity-swipe-navigation`.

## Tóm tắt ngắn

Các triệu chứng user mô tả có cơ sở trong code hiện tại:

- Register/login có gọi API qua controller/repository, nhưng UI không hiển thị trạng thái thành công hoặc lỗi.
- Nếu register/login API fail, exception không được catch ở UI/controller nên user gần như không thấy phản hồi.
- App không hiển thị user info sau khi đăng nhập. Drawer chỉ đổi từ `Register/Sign in` sang `Sign out`, không render `identifier`, `displayName`, hoặc `userId`.
- Swipe ngang có handler, nhưng chỉ trigger khi vận tốc đủ lớn. Slow drag dễ bị ignore.
- Khi swipe gọi backend fail và local không có từ fallback, controller set `statusMessage` nhưng không clear `currentWord`; UI ưu tiên render `currentWord`, nên màn hình có thể giữ nguyên thẻ cũ và nhìn như đứng im.
- Backend deploy có thể truy cập được, nhưng mọi `/v1/*` phụ thuộc app credential signing. Nếu credential hoặc TLS/cert chain fail trên mobile, API sẽ fail; hiện mobile đang swallow lỗi trong word feed path.

## Hiện trạng OpenSpec

`openspec list --json` cho thấy:

- `add-user-identity-swipe-navigation`: complete, 44/44 tasks.
- `add-adaptive-proficiency-system`: in-progress, 66/97 tasks.

Vấn đề đang nằm ở vùng đã được đánh dấu complete của `add-user-identity-swipe-navigation`, nhưng trạng thái complete không đồng nghĩa UX runtime đã ổn.

## Luồng register/login hiện tại

```text
Drawer Register/Sign in
  -> _showIdentityDialog()
  -> LearningSessionController.register/signIn()
  -> WordRepository.registerUser/signInUser()
  -> BackendApiClient POST /v1/users/register or /v1/users/sign-in
  -> LocalDatabase.saveUserSession()
  -> notifyListeners()
```

Các file liên quan:

- `mobile/lib/src/ui/learning_screen.dart`
  - `_register()` gọi `widget.controller.register(...)`.
  - `_signIn()` gọi `widget.controller.signIn(...)`.
  - `_onControllerChanged()` chỉ show SnackBar cho `takeLevelChangeMessage()`, không show auth success/error.
- `mobile/lib/src/session/learning_session_controller.dart`
  - `register()` chỉ set `statusMessage = null`, await repository, set `userSession`, rồi `notifyListeners()`.
  - `signIn()` tương tự.
  - Không có `try/catch`, không có success message, không có error message.
- `mobile/lib/src/ui/learning_screen.dart`
  - Drawer chỉ nhận `isSignedIn: controller.userSession != null`.
  - Khi signed-in, UI chỉ hiện `Sign out`; không có user info.
- `mobile/lib/src/models/user_session.dart`
  - Có đủ `identifier`, `displayName`, `sessionToken`, nhưng UI chưa render.

## Vì sao register/login không có phản hồi

### 1. Không có feedback thành công

Sau register/sign-in thành công, controller chỉ update `userSession`. UI không hiện:

- SnackBar `Register successful` / `Signed in`.
- User info trong drawer.
- AppBar/session chip.
- Loading state riêng cho auth.

Vì vậy nếu drawer đóng lại và màn hình chính không thay đổi rõ ràng, user thấy như không có gì xảy ra.

### 2. Không có feedback lỗi

Nếu API trả lỗi hoặc network fail:

- `BackendApiClient.registerUser()` throw `BackendApiException`.
- `BackendApiClient.signIn()` throw `BackendApiException`.
- `LearningSessionController.register()` và `signIn()` không catch.
- `_register()` và `_signIn()` cũng không catch.

Kết quả: lỗi có thể chỉ xuất hiện trong debug console, không thành thông báo UI.

### 3. User info chưa được render

Model `UserSession` có `identifier` và `displayName`, nhưng drawer chỉ hiển thị `Sign out` khi `isSignedIn == true`. Không có chỗ nào render:

- `controller.userSession?.displayName`
- `controller.userSession?.identifier`
- `controller.userSession?.userId`

Triệu chứng "mở app ra vẫn không thấy hiển thị user info" là đúng với implementation hiện tại.

## Luồng swipe hiện tại

```text
Horizontal drag end
  velocity < -200  -> showNewWord()
  velocity >  200  -> showRecentReview()
  otherwise        -> ignored silently
```

Các file liên quan:

- `mobile/lib/src/ui/learning_screen.dart`
  - `LearningCardGestureSurface.onHorizontalDragEnd`
  - `velocity < -200` gọi `onNewWordSwipe`.
  - `velocity > 200` gọi `onRecentReviewSwipe`.
- `mobile/lib/src/session/learning_session_controller.dart`
  - `showNewWord()` gọi `repository.getNewWordWithFallback(...)`.
  - `showRecentReview()` gọi `repository.getRecentReviewWord(...)`, rồi fallback new word.
- `mobile/lib/src/data/word_repository.dart`
  - `getNewWordWithFallback()` catch mọi lỗi backend và fallback local.
  - Nếu local cũng không có từ, trả `null`.

## Vì sao swipe có thể nhìn như đứng im

### 1. Slow drag bị ignore

Code chỉ xử lý khi `details.primaryVelocity` vượt ngưỡng:

- nhỏ hơn `-200`: new word.
- lớn hơn `200`: recent review.

Nếu user "slide" chậm hoặc thả nhẹ, gesture không làm gì và không có feedback.

### 2. Direction semantics có thể đang ngược kỳ vọng

OpenSpec ghi:

- right-to-left: request new word.
- left-to-right: review recently learned.

User mô tả "slide-right từ mới không xuất hiện" có thể đang kỳ vọng left-to-right là new word. Nếu kỳ vọng sản phẩm là "slide right = từ mới", code hiện tại đang không khớp.

### 3. Backend lỗi bị nuốt trong word feed path

`WordRepository.getNewWordWithFallback()` catch toàn bộ lỗi từ `apiClient.fetchNewWords()` và không surface ra UI. Đây là đúng với mục tiêu fallback offline, nhưng hiện không có telemetry/UI notice đủ rõ để debug.

Nếu backend fail và local DB không có từ `new`, kết quả là `null`.

### 4. Stale card không bị clear

Trong `LearningSessionController._showWord()`:

- Khi `word == null`, code chỉ set `statusMessage = 'No local learning card is available.'`.
- Code không set `currentWord = null`.

Trong `LearningScreen.build()`:

- UI render `VocabularyCardView` nếu `controller.currentWord != null`.
- Chỉ render `statusMessage` khi `currentWord == null`.

Do đó nếu đang có một thẻ cũ, swipe fail sẽ vẫn hiển thị thẻ cũ. User thấy màn hình đứng im, dù nội bộ có set `statusMessage`.

## Backend/API findings

### 1. Backend có identity endpoints

`backend/src/app.js` có:

- `POST /v1/users/register`
- `POST /v1/users/sign-in`
- `POST /v1/users/sign-out`
- `GET /v1/words/next`
- `GET /v1/words/recent`
- `POST /v1/study-events`
- `POST /v1/study-events/sync`

### 2. `/v1/*` bắt buộc app credential headers

`backend/src/app.js` apply middleware:

```text
/v1
  -> rejectMissingCredentialHeaders
  -> captureRawBody
  -> appCredentialGuard
  -> parseJsonFromCapturedBody
  -> v1 router
```

Nếu thiếu hoặc sai app credential, backend trả:

```json
{ "error": "bad_request" }
```

Mobile có signing trong `BackendApiClient._signedHeaders()`.

### 3. Deploy probe

Không gọi register/login thật để tránh tạo user rác. Chỉ probe endpoint đọc:

- `PowerShell Invoke-WebRequest https://expat8.x51.vn/health`: `200 {"ok":true}`
- Node `fetch https://expat8.x51.vn/health`: fail TLS với `UNABLE_TO_VERIFY_LEAF_SIGNATURE`
- Node insecure TLS:
  - `/health`: `200`
  - unsigned `/v1/words/recent`: `400 {"error":"bad_request"}`
  - signed `/v1/words/recent` bằng default mobile credentials: `200` và có word item.

Kết luận:

- Server đang sống.
- App credential default trong source có vẻ khớp với server hiện tại cho signed read request.
- Có dấu hiệu TLS certificate chain không đầy đủ theo Node trust store. PowerShell/Windows trust được, nhưng vẫn nên kiểm tra trên Android/iOS thật vì TLS fail trên mobile sẽ làm mọi API call thất bại.

## Verification local

### Flutter

Không chạy được Flutter test local vì máy hiện không có `flutter` trong PATH:

```text
flutter : The term 'flutter' is not recognized...
```

### Backend

`npm test` trong `backend/` fail do runtime dependencies chưa được install trong workspace hiện tại:

```text
Cannot find package 'express'
Cannot find package 'pg'
```

`backend/package.json` và `package-lock.json` có khai báo `express` và `pg`, nên local cần chạy `npm ci` trước khi test.

## Test coverage gap

Mobile tests hiện có nhưng chưa cover đúng vấn đề user gặp:

- Có test API client parse register/sign-in response.
- Có test drawer hiển thị `Register/Sign in` hoặc `Sign out`.
- Có test gesture route right-to-left/left-to-right.
- Chưa có test register/sign-in failure hiển thị error.
- Chưa có test register/sign-in success hiển thị user info.
- Chưa có test stale `currentWord` khi swipe fail.
- Chưa có test slow horizontal drag bị ignore hoặc có fallback UX.
- Chưa có integration test chạy app thật với backend deploy/staging.

## Root cause candidates theo mức độ ưu tiên

### P0 - UX không surface auth result

Đây là nguyên nhân trực tiếp nhất cho "register/login không phản hồi".

Nên sửa:

- Thêm auth loading state.
- Catch error trong `_register`, `_signIn` hoặc controller.
- Show SnackBar/Dialog cho success/failure.
- Map HTTP error rõ:
  - `400`: input/app credential/bad request.
  - `401`: invalid credentials/session.
  - `409`: user exists.
  - timeout/network: cannot reach server.

### P0 - User info không được render

Đây là nguyên nhân trực tiếp cho "mở app không thấy user info".

Nên sửa:

- Drawer header hiển thị:
  - `displayName` nếu có.
  - fallback `identifier`.
  - trạng thái `Signed in`.
- AppBar có thể hiển thị user chip hoặc avatar nhỏ.
- Khi `loadInitial()` load saved session, UI phải render identity ngay.

### P0 - Swipe fail giữ nguyên stale card

Đây là nguyên nhân trực tiếp cho "slide left/right vẫn đứng im" khi backend/local không trả card mới.

Nên sửa:

- Khi `word == null`, cân nhắc set `currentWord = null` hoặc show overlay/banner trên card cũ.
- Trả kết quả từ repository gồm `word`, `source`, `error`, `fallbackReason` thay vì chỉ `VocabularyWord?`.
- Show message rõ: "Không lấy được từ mới. Kiểm tra mạng hoặc backend."

### P1 - Gesture threshold/semantics chưa thân thiện

Nên sửa:

- Xác nhận lại product semantics:
  - Nếu user kỳ vọng "slide right = từ mới", đổi mapping hiện tại.
  - Nếu giữ OpenSpec hiện tại, thêm hint UI hoặc icon hướng.
- Thêm fallback button rõ ràng:
  - "New word"
  - "Review"
- Giảm phụ thuộc vào velocity hoặc dùng `Dismissible`/`PageView`/drag distance threshold.

### P1 - API errors bị swallow quá rộng

Offline fallback là đúng, nhưng user-triggered operations cần feedback.

Nên sửa:

- Auth endpoints không được silent fail.
- Word feed có thể fallback silent nhưng cần telemetry/debug status.
- Tách `NetworkException`, `TimeoutException`, `InvalidCredentialException`, `BackendStatusException`.

### P1 - Runtime/deploy checks chưa đủ

Nên sửa:

- Cài dependencies bằng `npm ci` trong backend test environment.
- Cài Flutter SDK hoặc chạy CI mobile tests.
- Thêm smoke test trên staging/prod read-only:
  - `/health`
  - signed `/v1/words/recent`
  - signed `/v1/proficiency?device_id=...`
- Kiểm tra TLS chain bằng Android/iOS device thật.

## Đề xuất change tiếp theo

Nên tạo OpenSpec change riêng, ví dụ:

```text
fix-mobile-auth-feedback-and-swipe-state
```

Scope đề xuất:

1. Auth UX:
   - Loading state khi register/sign-in/sign-out.
   - Success SnackBar.
   - Error SnackBar/Dialog với message theo status code.
   - Drawer header hiển thị user info.

2. Swipe UX:
   - Không giữ stale card khi request fail mà không có fallback.
   - Hiển thị message rõ nếu không có từ mới/review.
   - Confirm hoặc đổi gesture direction theo kỳ vọng sản phẩm.
   - Thêm visible buttons cho new/review để debug và accessibility.

3. Observability:
   - Log/telemetry cho auth success/failure.
   - Log/telemetry cho word feed backend failure, local fallback hit/miss.

4. Tests:
   - Widget test auth success shows user info.
   - Widget test auth failure shows error.
   - Controller test swipe fail clears/shows no-card state.
   - Widget test slow drag behavior.
   - Integration/smoke test with signed backend client.

## Kết luận

Backend identity API đã tồn tại và signed read endpoint deploy có thể trả dữ liệu. Vấn đề chính hiện tại không chỉ là backend, mà là mobile UX/state handling:

- Auth result không được surface.
- User session không được render thành user info.
- Swipe fail bị biểu hiện như đứng im vì lỗi bị swallow và card cũ vẫn được ưu tiên render.

Nên ưu tiên sửa mobile feedback/state trước, đồng thời kiểm tra TLS chain và đảm bảo CI/dev environment chạy được cả `npm test` và `flutter test`.
## Follow-up implemented on 2026-05-05

OpenSpec change: `fix-mobile-auth-feedback-and-swipe-state`

Implemented fixes:

- Added controller auth state: in-progress flag, success message, error
  message, and one-shot user feedback message for SnackBar rendering.
- Register and sign-in now catch backend/network errors and map common status
  codes to user-facing messages:
  - `409` / `user_exists`: account already exists.
  - `401` / `invalid_credentials`: email or password is incorrect.
  - `400` / `bad_request`: request rejected.
  - other backend/network failures: check connection and try again.
- Failed register/sign-in preserves the previous valid session or stays
  anonymous when there was no previous session.
- Sign-out still clears local session through the repository's anonymous
  fallback behavior; if server confirmation fails after local clear, the UI
  reports local sign-out.
- Drawer now renders signed-in user info using display name with identifier
  fallback, including stored sessions loaded on app start.
- Learning lookup now returns a structured result with source and message, so
  backend success, local fallback, and fallback miss are distinguishable.
- When no new/review card is available, `currentWord` is cleared and the
  no-card/retry message is visible instead of leaving a stale card on screen.
- Horizontal swipe semantics are encoded in UI code and tests:
  right-to-left means new word, left-to-right means review.
- Slow horizontal drags now trigger by drag distance as well as velocity.
- Visible `New Word` and `Review` buttons plus a swipe hint were added.
- Telemetry events were added for auth outcomes, new-word fallback miss, and
  recent-review hit/miss.
- Added mobile controller/widget tests for auth feedback, drawer user info,
  stale-card clearing, slow drag, and visible learning actions.
- Added `scripts/smoke-deployed-backend.mjs` as a read-only deployed smoke
  check for `/health`, unsigned `/v1/words/recent` rejection, signed
  `/v1/words/recent`, and HTTPS TLS trust through Node fetch.

Verification notes from this workspace:

- `dart format` could not run because `dart` is not available in PATH.
- `flutter test` could not run because `flutter` is not available in PATH.
- `npm ci` completed in `backend/`.
- `npm test` completed in `backend/`: 43 tests, 41 pass, 2 skipped, 0 failed.
- `node scripts/smoke-deployed-backend.mjs` failed with
  `UNABLE_TO_VERIFY_LEAF_SIGNATURE`, confirming the deployed HTTPS certificate
  chain is not accepted by Node's trust store.
- Re-running the smoke script with `NODE_TLS_REJECT_UNAUTHORIZED=0` passed
  `/health`, unsigned `/v1/words/recent` rejection, and signed
  `/v1/words/recent`; this isolates app credential behavior from the TLS
  chain problem and is not a TLS pass.
