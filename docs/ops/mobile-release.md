# Phát hành app Android

Bản build chính thức **chỉ** được tạo bởi workflow GitHub Actions `Android Release` (`.github/workflows/android-release.yml`), vì keystore và secrets build nằm ở GitHub. Máy dev không build được bản release ký chính thức (thiếu keystore; NDK chưa chấp nhận license).

App có hai đường nhận bản mới, **cả hai đều phải làm**:

| Đường | App gọi | Cần làm |
|---|---|---|
| Banner "có bản mới" | GitHub API `repos/duvu/expat8/releases/latest` | Workflow tự tạo GitHub Release |
| Màn *Check for updates* (tải và cài APK) | Backend `GET /v1/releases/latest?platform=android` | Upload APK lên backend (bước 4) |

## 1. Chuẩn bị

- [ ] Backend production đã có mọi endpoint mà bản app này gọi ([deploy.md](deploy.md)). Nếu backend cũ hơn, app nhận 404 và **bỏ** các sự kiện đó thay vì thử lại.
- [ ] Kiểm tra local:
  ```bash
  cd mobile && flutter analyze && flutter test
  ```
- [ ] Chọn số phiên bản: `version: <major>.<minor>.<patch>+<build>` trong `mobile/pubspec.yaml`. `build` (versionCode) **phải tăng** mỗi lần; Android từ chối cài bản có versionCode nhỏ hơn bản đang có.

## 2. Bump version qua PR

```bash
git checkout main && git pull
git checkout -b chore/release-1.3.5
sed -i 's/^version: .*/version: 1.3.5+9/' mobile/pubspec.yaml
git commit -m "chore(mobile): bump version to 1.3.5+9" -- mobile/pubspec.yaml
git push -u origin chore/release-1.3.5
gh pr create --base main --title "chore(mobile): bump version to 1.3.5+9" --body "Release 1.3.5"
gh pr merge --merge --delete-branch
```

## 3. Tag và build

```bash
git checkout main && git pull
grep '^version:' mobile/pubspec.yaml          # phải là 1.3.5+9
git tag -a v1.3.5 -m "Release 1.3.5"
git push origin v1.3.5
gh run list --workflow android-release.yml -L 1
gh run watch <run-id> --exit-status
gh release view v1.3.5 --json url,assets --jq '.url, (.assets[]|"\(.name) \(.size)")'
```

Workflow kiểm tra tag khớp `pubspec.yaml`, build APK và AAB đã ký với các `--dart-define` lấy từ secrets (`BACKEND_BASE_URL`, `APP_CREDENTIAL_APP_ID`, `APP_CREDENTIAL_SECRET`, `NEW_WORD_TIMEOUT_SECONDS`, `APP_LOG_LEVEL=info`, `APP_VERSION_CODE/NAME`), rồi tạo GitHub Release kèm release notes tự sinh. Thời gian khoảng 10 phút.

Kết quả đúng: release có `app-release.apk` (~70 MB) và `app-release.aab` (~64 MB).

## 4. Đưa APK lên backend (cập nhật trong app)

```bash
gh release download v1.3.5 -p app-release.apk -D /tmp/expat8-1.3.5
set -a; . ~/.config/expat8/ops.env; set +a
node scripts/admin-request.mjs POST /v1/admin/releases \
  --file /tmp/expat8-1.3.5/app-release.apk \
  --header x-expat8-release-platform=android \
  --header x-expat8-release-version-code=9 \
  --header x-expat8-release-version-name=1.3.5
```

Kết quả đúng: `HTTP 201` kèm `sha256`. Backend giữ tối đa 5 bản mỗi nền tảng, tự xoá bản cũ nhất. Kiểm tra:

```bash
node scripts/ops-check.mjs    # dòng "in-app update matches GitHub release" phải OK
```

## 5. Kiểm tra trên máy thật

- [ ] Cài APK lên máy đang chạy bản trước: banner báo có bản mới, *Check for updates* tải và cài được.
- [ ] Mở app lần đầu sau khi cập nhật: dữ liệu cũ còn đủ; đăng nhập, học, đồng bộ bình thường.
- [ ] Tắt mạng: học, chơi game vẫn chạy; bật lại mạng thì hàng đợi đồng bộ hết (xem *Logs* trong app).

## Khi có sự cố

| Tình huống | Cách xử lý |
|---|---|
| Workflow lỗi *tag không khớp pubspec* | Xoá tag (`git push --delete origin v1.3.5 && git tag -d v1.3.5`), sửa pubspec qua PR, tag lại. Chỉ làm được khi **chưa** có GitHub Release |
| Workflow lỗi ở bước build | Sửa lỗi qua PR, **ra bản vá mới** (`1.3.6+10`); không dời tag đã có release |
| Lỗi secrets/keystore | Xem [secrets.md](secrets.md#keystore-android). Sửa secret rồi `gh run rerun <run-id>` |
| Bản đã phát hành có lỗi nghiêm trọng | 1) Gỡ bản khỏi cập nhật trong app: `node scripts/admin-request.mjs GET /v1/admin/releases`, rồi `DELETE /v1/admin/releases/<id>`. 2) Chuyển GitHub Release sang pre-release để banner ngừng báo: `gh release edit v1.3.5 --prerelease`. 3) Ra bản vá có versionCode **lớn hơn** |

Không có "hạ phiên bản" trên Android: máy đã cài 1.3.5 không cài được 1.3.4 nếu không gỡ app (gỡ app sẽ mất dữ liệu chưa đồng bộ). Vì vậy luôn sửa tiến, không lùi.

## Build thủ công (chỉ để thử)

Build debug hoặc thử cấu hình trên máy dev, **không phát hành**:

```bash
cd mobile
flutter run \
  --dart-define=BACKEND_BASE_URL=<URL> \
  --dart-define=APP_CREDENTIAL_APP_ID=<APP_ID> \
  --dart-define=APP_CREDENTIAL_SECRET=<SECRET> \
  --dart-define=NEW_WORD_TIMEOUT_SECONDS=5
```

Mọi giá trị `--dart-define` được biên dịch vào app; đổi giá trị nào thì phải build lại. Emulator Android cần URL public; IP LAN/VPN chỉ dùng được cho máy thật cùng mạng.

## Google Play

Chưa phát hành lên Play Store. Điều kiện trước khi làm nằm ở [canonical-release-path.md](../canonical-release-path.md#stage-3--play-store-deferred-public-distribution).

> Đã kiểm chứng (2026-09-29): quy trình 2–3 đã chạy cho v1.3.3 và v1.3.4. Bước 4 đã chạy thử với backend local (upload 201, `/v1/releases/latest` trả bản mới, thiếu admin token trả 403).
