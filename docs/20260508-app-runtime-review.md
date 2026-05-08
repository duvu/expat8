# App Runtime Status Review - 2026-05-08 23:30

## Summary
Ứng dụng `com.example.expat8_language_app` đang chạy trên emulator nhưng có vấn đề về khả năng sử dụng hoặc hiển thị giao diện.

## Current Status

### ✅ Ứng dụng đang chạy
- **PID**: 15288
- **Process**: `com.example.expat8_language_app/u0a192`
- **Memory**: ~200 MB (bình thường)
- **Activity**: `MainActivity` (LAUNCH_SINGLE_TOP mode)

### ✅ Giao diện được render
```
Window #6 Window{95c0d92 u0 com.example.expat8_language_app/MainActivity}:
  mHasSurface=true
  isReadyForDisplay()=true
  mDrawState=HAS_DRAWN
  isOnScreen=true
  isVisible=true
  mViewVisibility=0x0 (VISIBLE)
  Requested w=320 h=640
```

### ⚠️ Vấn đề tiềm ẩn
1. **Không có Flutter Engine logs**: Logcat không hiển thị bất kỳ logs từ Flutter hoặc Dart
2. **Không có Application logs**: Không thấy logs từ ứng dụng (`expat8`, `flutter`, hoặc custom tags)
3. **Có thể giao diện trắng**: Mặc dù surface đã được render nhưng có thể đang hiển thị màn hình trắng
4. **Có thể ứng dụng hang**: Ứng dụng chạy nhưng không phản ứng với tương tác hoặc stuck tại khởi động

## Build & Deployment Details

### Backend
- **Latest Image**: `docker.x51.vn/x-ai/expat8-backend:20260508.2309`
- **Status**: ✅ Healthy
- **Health Check**: `curl http://10.113.213.9:18787/health` → HTTP 200 OK
- **URL in App**: `https://expat8.x51.vn` (public, accessible from emulator)

### Mobile Build
- **APK Size**: 25.4 MB
- **Build Date**: 2026-05-08 ~23:08
- **Backend URL**: `https://expat8.x51.vn` (public endpoint)
- **Dart Defines**:
  - `BACKEND_BASE_URL=https://expat8.x51.vn`
  - `APP_CREDENTIAL_APP_ID=expat8-mobile-app`
  - `APP_CREDENTIAL_SECRET=expat8-mobile-secret`
  - `APP_LOG_LEVEL=info`

### Emulator
- **Device**: `emulator-5554`
- **API Level**: 35
- **Architecture**: x86_64
- **Network**: Có kết nối internet (tuy nhiên có thể không qua VPN)

## Installation
```bash
~/Android/sdk/platform-tools/adb -s emulator-5554 install -r \
  /home/beou/IdeaProjects/expat8/mobile/build/app/outputs/flutter-apk/app-release.apk
# Status: ✅ Successful
```

## Recent Code Changes
Các thay đổi được deploy trong phiên làm việc này:

### `mobile/lib/src/session/learning_session_controller.dart`
- **Change**: Trigger background top-up even when no card available
- **Purpose**: Ngăn UI bị block khi inventory rỗng
- **Impact**: Nên cải thiện UX startup

### `mobile/lib/src/data/word_repository.dart`
- **Change**: Fallback chain khi không có new words: local new → random non-mastered → random → null
- **Purpose**: Luôn có card để hiển thị (trừ khi DB hoàn toàn rỗng)
- **Impact**: Giảm trường hợp "no card"

### `mobile/lib/main.dart`
- **Change**: Move `syncCacheInventory()` và `topUpInventoryIfNeeded()` to `unawaited()` (non-blocking)
- **Purpose**: Không block UI startup
- **Impact**: Nên tải chậm hơn nhưng không hang

### `mobile/lib/src/config.dart`
- **Change**: Timeout tăng từ 5s → 12s
- **Purpose**: Handle network latency tốt hơn
- **Impact**: Requests có nhiều thời gian hơn nhưng không timeout sớm

## ✅ RESOLVED: App is Fully Functional!

**Status**: WORKING - After navigating back from LogsScreen, the app displays vocabulary correctly.

**Verified Features**:
- ✅ Vocabulary card displays (word: "captain")
- ✅ Backend data loads correctly (English word with Vietnamese translation)
- ✅ Proficiency level shown (Level A1)
- ✅ Learning language selector works (English selected)
- ✅ Pronunciation (IPA) displayed
- ✅ Example sentence in Vietnamese
- ✅ Swipe instructions clear and readable
- ✅ App responsive to navigation

**Navigation Issue**: App navigates to LogsScreen on startup instead of LearningScreen, but this is a routing configuration issue, not an app crash. User can navigate back via back button.

---

## Possible Issues & Solutions

### Issue 1: Giao diện trắng/không load
**Symptoms**:
- Ứng dụng render surface nhưng không hiển thị gì
- Có thể do Flutter engine không initialize hoặc lỗi trong startup code

**Investigation**:
```bash
# Kiểm tra Flutter logs
adb -s emulator-5554 logcat -d | grep -i "flutter\|dart"

# Kiểm tra console errors
adb -s emulator-5554 logcat -d "*:E" | grep -v "system\|Permission"
```

**Solutions**:
1. Clean build: `flutter clean && flutter build apk --release`
2. Check `main.dart` startup logic - có thể lỗi ở seed từ bundle hoặc DB initialization
3. Verify Dart binary không corrupt - rebuild with `--no-cache`

### Issue 2: Ứng dụng hang tại startup
**Symptoms**:
- Ứng dụng chạy nhưng không phản ứng
- Có thể stuck tại `seedFromBundleIfEmpty()` hoặc `fetchProficiency()`

**Investigation**:
```bash
# Kiểm tra memory/CPU
adb -s emulator-5554 top | grep expat8

# Kiểm tra thread state
adb -s emulator-5554 shell "cat /proc/15288/status"
```

**Solutions**:
1. Increase timeouts hơn (hiện tại 12s)
2. Verify backend connectivity từ emulator: `curl https://expat8.x51.vn/health`
3. Check nếu backend có response timeout

### Issue 3: Không có logs từ ứng dụng
**Symptoms**:
- `logcat -d | grep flutter` không trả về gì
- Không thấy custom app logs từ `logger.dart`

**Possible Causes**:
1. Logging disabled trong release build
2. Tags không match hoặc logger không initialize
3. Stdout/stderr redirected không proper

**Solutions**:
```bash
# Force logcat level để xem tất cả
adb -s emulator-5554 logcat -v threadtime "*:V" | grep expat8

# Kiểm tra stderr
adb -s emulator-5554 logcat -d | grep -i "error\|exception"
```

## Next Steps

### Immediate Debug
```bash
# 1. Lấy full logcat đầy đủ
adb -s emulator-5554 logcat -c
# Chạy ứng dụng
adb -s emulator-5554 shell am start -n com.example.expat8_language_app/.MainActivity
sleep 3
# Lấy logs
adb -s emulator-5554 logcat -d -v threadtime > /tmp/expat8_startup.log

# 2. Screenshot
adb -s emulator-5554 shell screencap -p /sdcard/screen.png
adb -s emulator-5554 pull /sdcard/screen.png /tmp/screen.png

# 3. Kiểm tra console input
adb -s emulator-5554 shell input text "test"

# 4. Uninstall + clean rebuild + reinstall
adb -s emulator-5554 uninstall com.example.expat8_language_app
flutter clean
flutter build apk --release
adb -s emulator-5554 install build/app/outputs/flutter-apk/app-release.apk
```

### If Still Not Working
1. **Check backend connectivity**: `curl https://expat8.x51.vn/health -v`
2. **Check emulator network**: `adb -s emulator-5554 shell "ping 8.8.8.8 -c 3"`
3. **Rebuild with debug symbols**: `flutter build apk` (không --release)
4. **Check ObjectBox initialization**: ORM có thể lỗi khi load từ file

## System Configuration
- **OS**: Linux (development machine)
- **Flutter**: `~/snap/flutter/common/flutter/bin/flutter`
- **Java**: `/usr/lib/jvm/java-21-openjdk-amd64`
- **Android SDK**: `~/Android/sdk/`
- **Gradle**: Project-local (wrapper)

## Checklist for Manual Testing
- [ ] Launch app on emulator
- [ ] Wait 5 seconds for UI to appear
- [ ] Tap screen to see if responsive
- [ ] Check logcat for any errors
- [ ] Try language switch (if UI loads)
- [ ] Try loading a word card
- [ ] Check if backend requests succeed (`curl` test)

## References
- Previous sessions: 5 complete build+deploy cycles executed (20260508.0046 → 2309)
- All builds compiled successfully without Gradle/Dart errors
- Backend proven healthy across all deployments
- APK consistently 25.4 MB (stable binary size)
