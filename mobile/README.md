# Expat8 Mobile App

Flutter client for the Expat8 vocabulary learning MVP.

## Current Architecture

- Local persistence uses ObjectBox through `LocalDatabase`.
- The app signs every `/v1/*` backend request with app credential headers.
- Anonymous users persist an `anonymous_<uuid>` device id locally.
- Signed-in users add a bearer session token while keeping the same device id
  for offline/cache context.
- Card refill uses `POST /v1/learning/cards` with `card_mode: "new"`.
- Duplicate avoidance is backend-owned through learner state and
  `PUT /v1/user-word-cache`; the mobile app does not send word exclusion lists
  for refill.

## Development

```bash
flutter pub get
flutter test
flutter run \
  --dart-define=BACKEND_BASE_URL=http://localhost:8787 \
  --dart-define=APP_CREDENTIAL_APP_ID=expat8-mobile-app \
  --dart-define=APP_CREDENTIAL_SECRET=expat8-mobile-secret
```

ObjectBox native libraries are required for desktop/unit-test runs. In this
repo, Linux test runs expect `mobile/lib/libobjectbox.so` to be present.

After editing ObjectBox entities, regenerate bindings:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```
