# Investigation: App "treo" sau vài từ

**Ngày:** 2026-05-09
**Trạng thái:** Đã fix ✓

---

## Triệu chứng

User cài app mới, mở lên thấy thẻ đầu tiên load OK. Sau **vài lần swipe**, hệ thống "treo": gestures không phản hồi, không có thẻ tiếp theo. App không crash, chỉ stop responding. Restart → lại trơn vài thẻ → treo.

User yêu cầu:
1. Mobile **luôn** trả ra từ tiếp theo trong **mọi trường hợp**, kể cả mất mạng
2. Nếu hết từ chưa học → random từ đã học (chưa được mark "đã nhớ") để hiển thị
3. **Không bao giờ** ngừng cứng màn hình

---

## Phân tích nguyên nhân

### Nguyên nhân chính: log pruning chạy đồng bộ trên mỗi log entry

`mobile/lib/main.dart` cấu hình `PersistedLogger.write` để ghi log + prune trong cùng callback:

```dart
final logger = PersistedLogger(
  minimumLevel: AppLogLevel.fromName(config.logLevel),
  write: (entry) async {
    await database.persistLogEntry(entry);
    await database.pruneLogs(  // ← chạy O(n log n) mỗi lần ghi log
      maxEntries: config.logMaxEntries,
      maxAge: config.logRetention,
    );
  },
);
```

`pruneLogs` thực hiện:
```dart
final all = _logs.getAll();              // load TOÀN BỘ logs vào memory
for (final entry in all) { ... }         // iterate
final remaining = _logs.getAll();        // load lại lần 2
remaining.sort(...);                     // sort O(n log n)
```

Mỗi swipe controller emit **5+ log entries** (`session.gesture.*`, `session.card_selection.start/selected`, `new_word.local.hit`, `local_words.upsert`, …). Ban đầu n = 0 → nhanh. Sau vài chục swipe → n = vài trăm → mỗi log call mất tới 50-200ms → mỗi swipe block UI 250ms-1s. Sau vài trăm swipe → n = vài nghìn → app feels frozen.

Ngoài ra `await write(entry)` trong `PersistedLogger.log` khiến **caller block** trên mỗi log call. Toàn bộ hot-path UI (controller, repository, swipe handler) đều stall theo log throughput.

### Nguyên nhân phụ #1: catch handler có thể throw → `isLoading` kẹt

`_showSelectedCard` đã có `try/catch` nhưng KHÔNG có `finally`. Catch handler awaits `_logger.warning` (đường log chậm ở trên). Nếu log call throw (ví dụ: ObjectBox tạm lock, disk write fail), isLoading bị bỏ ở `true` → gesture surface (`isEnabled: !isLoading`) bị disable vĩnh viễn → màn hình treo.

### Nguyên nhân phụ #2: gesture surface bị khoá khi loading kẹt

`learning_screen.dart` truyền `isEnabled: !controller.isLoading` xuống `LearningCardGestureSurface`. Khi `isLoading` stuck=true (do nguyên nhân phụ #1), tất cả gesture bị bỏ qua. UI không phản hồi swipe nào.

### Đã có sẵn (không phải nguyên nhân)

- Fallback chain: `getNewWordWithFallbackResult` đã có 3 cấp (newWord → randomNotMastered → randomWord). Path "review-first" cũng cascade về `getNewWordWithFallbackResult`. Nên DB **không bao giờ** trả null (trừ khi rỗng tuyệt đối).
- Network calls (`fetchProficiency`, `topUpInventoryIfNeeded`) đã chuyển fire-and-forget. Không phải nguyên nhân chính.

---

## Giải pháp

### 1. Tách log write khỏi prune

`PersistedLogger.write` chỉ làm **1 việc**: persist entry. Không await prune. Prune chuyển sang **maintenance timer riêng** (mỗi vài phút) hoặc **on-demand** qua API.

```dart
// main.dart
final logger = PersistedLogger(
  minimumLevel: ...,
  write: (entry) => database.persistLogEntry(entry),  // chỉ persist
);

// LocalDatabase.startMaintenanceTimer
Timer.periodic(Duration(minutes: 5), (_) {
  unawaited(pruneLogs(...));
});
```

Per-log overhead: từ O(n log n) → O(1).

### 2. Swallow log I/O errors

Log write **không bao giờ** throw lên caller. Nếu disk full / DB locked → silently drop log entry, không phá flow chính.

```dart
// PersistedLogger
try {
  await write(entry);
} catch (_) {
  // Logging must never break the app's hot path.
}
```

### 3. `try/finally` cho `_showSelectedCard`

`isLoading` được reset trong `finally` block, kể cả khi catch handler tự throw.

```dart
isLoading = true;
notifyListeners();
try {
  ...
} catch (error) {
  ... (best-effort log, swallow errors here)
} finally {
  isLoading = false;
  notifyListeners();
}
```

Loại bỏ vĩnh viễn case "isLoading stuck".

### 4. Watchdog backup trên `_showSelectedCard`

Đặt timeout (e.g., 8 giây): nếu sau 8s vẫn `isLoading=true`, force reset. Defense-in-depth phòng các bug chưa biết.

---

## Files đã fix

| File | Thay đổi |
|------|----------|
| `mobile/lib/src/logging/logger.dart` | `PersistedLogger.log` wrap `await write(entry)` trong try/catch — log I/O không bao giờ propagate error lên hot path |
| `mobile/lib/main.dart` | Log write chỉ gọi `database.persistLogEntry`; thêm `Timer.periodic(5 phút)` chạy `pruneLogs` ngầm + 1 lần ngay khi startup |
| `mobile/lib/src/session/learning_session_controller.dart` | `try/finally` quanh `_showSelectedCard`; watchdog `Timer(8s)` force reset `isLoading`; helper `_safeLog` swallow lỗi của log call |
| `mobile/test/logging_test.dart` | Test mới: logger swallow throwing write |
| `mobile/test/learning_session_controller_test.dart` | 2 test mới: isLoading reset khi logger throw, 5 swipe back-to-back không stuck |

## Kết quả

- `dart analyze`: clean
- Tests: **102/102 pass** (thêm 3 tests cover regression)
- Per-log overhead: O(n log n) → O(1) (chỉ persist, không prune trong hot path)
- `isLoading` được đảm bảo reset bởi 3 lớp phòng hờ:
  1. `_showWord` set false khi success
  2. `try/finally` set false nếu exception bất kỳ
  3. Watchdog timer 8s force reset nếu cả 2 trên bằng cách nào đó fail

## Đảm bảo "không bao giờ treo"

| Tình huống | Hành xử mới |
|------------|-------------|
| Log write fail (disk full, DB locked) | Logger swallow lỗi, hot path tiếp tục |
| Card selection throw (DB query lỗi) | Catch + log + finally reset isLoading; user thấy empty message, có thể swipe lại |
| Log call trong catch tự throw | `_safeLog` swallow; finally vẫn chạy |
| Bug chưa biết khiến isLoading stuck > 8s | Watchdog timer force reset, gestures hoạt động lại |
| Hết từ chưa học | Random non-mastered → random ANY (đã có) → user vẫn thấy thẻ |
| Mất mạng | DB reads không cần network; topup/proficiency là background |
