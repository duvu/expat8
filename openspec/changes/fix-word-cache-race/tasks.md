## 1. Backend — Fix word-cache race condition

- [x] 1.1 In `backend/src/postgres_word_store.js`, locate the `INSERT INTO user_cached_words` statement inside `replaceCachedWordIds` and add `ON CONFLICT DO NOTHING` so concurrent inserts of the same word id are silently skipped
- [x] 1.2 Add a unit test (or extend existing test) in `backend/test/` that calls `replaceCachedWordIds` twice concurrently with the same device id and word ids and asserts both calls resolve without error

## 2. Backend — Wire dead rate-limit config

- [x] 2.1 In `backend/src/rate_limit.js`, update `createRateLimiters()` to accept an `opts` object and use `opts.registerMax` / `opts.registerWindowMs` and `opts.signInMax` / `opts.signInWindowMs` (with the existing hard-coded values as fallback defaults)
- [x] 2.2 In `backend/src/runtime.js`, pass the relevant `config.authRateLimitRegister` and `config.authRateLimitSignIn` values into the `createRateLimiters()` call

## 3. Backend — Distinguish "user not found" in 401 sign-in response

- [x] 3.1 In `backend/src/postgres_word_store.js` (or wherever `findUserByIdentifier` is called for sign-in), return a flag or throw a typed error that distinguishes "identifier not found" from "wrong password"
- [x] 3.2 In the sign-in route handler in `backend/src/app.js`, check the typed error and include `"reason": "user_not_found"` in the 401 response body when the identifier does not exist

## 4. Mobile — Improve auth error messages

- [x] 4.1 In `mobile/lib/src/session/learning_session_controller.dart`, update `_authFailureMessage` to check for `statusCode == 401` and `backendError.reason == "user_not_found"` — return "No account found. Please register." in that case
- [x] 4.2 In `_authFailureMessage`, update the `statusCode == 429` branch to return "Too many attempts. Please wait a moment and try again." instead of the generic "Server returned 429"
- [ ] 4.3 Run `flutter test` and confirm no regressions

## 5. Verification

- [ ] 5.1 Run `cd backend && npm test` and confirm all tests pass
- [ ] 5.2 Manually verify: fresh emulator session → app starts without 500 in backend log for `PUT /v1/user-word-cache`
- [ ] 5.3 Manually verify: sign-in with unknown email shows "No account found" message in the app
