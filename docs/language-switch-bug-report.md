# Bug Report: Language Switch Không Có Hiệu Lực

**Ngày:** 2026-05-07  
**Trạng thái:** Đã fix ✓

---

## Tóm tắt

Khi người dùng chọn ngôn ngữ học mới (ví dụ: Vietnamese → Chinese) qua `LearningLanguageSelector`, UI cập nhật nhãn hiển thị đúng, nhưng hệ thống vẫn tiếp tục trả về từ vựng tiếng Anh (`en`). Ngôn ngữ đã chọn không được truyền xuống bất kỳ API call hay DB query nào.

---

## Phân tích nguyên nhân

Có **3 lớp bug** độc lập, đều phải sửa để language switch hoạt động đúng.

### Bug 1 — Controller không reload từ sau khi đổi ngôn ngữ

**File:** `mobile/lib/src/session/learning_session_controller.dart:55-64`

```dart
Future<void> setActiveLearningLanguage(String language) async {
  if (!_config.supportedLearningLanguages.contains(language)) return;
  if (_activeLearningLanguage == language) return;
  _activeLearningLanguage = language;
  notifyListeners();  // ← chỉ cập nhật nhãn UI, KHÔNG reload từ
}
```

Sau khi đổi ngôn ngữ, `showNewWord()` không được gọi → thẻ từ đang hiển thị vẫn là ngôn ngữ cũ, không có thẻ mới nào được load cho ngôn ngữ mới.

Thêm nữa, `_activeLearningLanguage` **không bao giờ được truyền** vào các lời gọi repository:

```dart
// Tất cả các lời gọi này không nhận language parameter:
repository.getNewWordWithFallbackResult(deviceId: _deviceId)
repository.getReviewWord(now)
repository.getDifficultRelearnWord(now)
repository.getRecentReviewWordResult(now)
```

### Bug 2 — Repository không truyền language xuống API

**File:** `mobile/lib/src/data/word_repository.dart:379-401`

```dart
Future<List<VocabularyWord>> refillLearningCards({
  required String deviceId,
  int limit = 10,
}) async {
  final batch = await apiClient.fetchLearningCards(
    deviceId: deviceId,
    limit: limit.clamp(1, 100).toInt(),
    // ← targetLanguage KHÔNG được truyền → backend dùng default 'en'
  );
}
```

Cả `refillLearningCards()` và `prefetchBatch()` đều gọi `apiClient.fetchLearningCards()` mà không truyền `targetLanguage`. Backend API client có parameter này với default `'en'`:

```dart
// backend_api_client.dart:177
Future<LearningCardBatch> fetchLearningCards({
  required String deviceId,
  int limit = 10,
  String targetLanguage = 'en',  // ← luôn là 'en'
  ...
```

Tương tự, `fetchProficiency` cũng hardcode `language = 'en'`.

### Bug 3 — Database queries không filter theo language

**File:** `mobile/lib/src/data/local_database.dart`

Tất cả các query lấy từ vựng từ local DB đều **bỏ qua trường `language`**:

| Method | Vấn đề |
|--------|--------|
| `nextNewWord()` | Không filter `language` → trả từ của mọi ngôn ngữ |
| `nextDueReviewWord()` | Không filter `language` |
| `recentlyLearnedReviewWord()` | Không filter `language` |
| `nextDifficultRelearnWord()` | Không filter `language` |
| `countUnstudiedNewWords()` | Không filter `language` → đếm sai khi cache có nhiều ngôn ngữ |

Ví dụ:
```dart
Future<VocabularyWord?> nextNewWord() async {
  final rows = _localWords
      .query(LocalWordEntity_.status.equals(WordStatus.newWord.name))
      // ← thiếu: .and(LocalWordEntity_.language.equals(language))
      .build()
      .find();
}
```

---

## Luồng dữ liệu trước khi fix

```
User chọn "Vietnamese"
    ↓
setActiveLearningLanguage('vi')
    ↓
_activeLearningLanguage = 'vi' + notifyListeners()
    ↓
UI label: "Vietnamese" ✓
    ↓
[DỪNG TẠI ĐÂY — language không đi tiếp]
    ↓
showNewWord() → getNewWordWithFallbackResult()  [không có language]
    ↓
refillLearningCards()  [không có language]
    ↓
fetchLearningCards(targetLanguage: 'en')  [hardcode 'en']
    ↓
Backend trả về từ tiếng Anh ✗
```

---

## Fix thực hiện

### 1. `local_database.dart` — Thêm language filter vào DB queries

Các method `nextNewWord`, `nextDueReviewWord`, `recentlyLearnedReviewWord`, `nextDifficultRelearnWord`, `countUnstudiedNewWords` được thêm tham số `String language` và filter theo `LocalWordEntity_.language`.

### 2. `word_repository.dart` — Truyền language qua repository

Các method `refillLearningCards`, `prefetchBatch`, `getNewWordWithFallbackResult`, `getReviewWord`, `getRecentReviewWordResult`, `getDifficultRelearnWord` được thêm `String language` và truyền xuống API + DB.

### 3. `learning_session_controller.dart` — Wire language + reload

- Tất cả lời gọi repository nhận `_activeLearningLanguage`
- `setActiveLearningLanguage` gọi `showNewWord()` sau khi đổi ngôn ngữ để load từ mới ngay lập tức

---

## Luồng dữ liệu sau khi fix

```
User chọn "Vietnamese"
    ↓
setActiveLearningLanguage('vi')
    ↓
_activeLearningLanguage = 'vi' + notifyListeners()
    ↓
showNewWord()  ← GỌI NGAY ĐỂ RELOAD
    ↓
getNewWordWithFallbackResult(language: 'vi')
    ↓
refillLearningCards(language: 'vi')
    ↓
fetchLearningCards(targetLanguage: 'vi')
    ↓
Backend trả về từ tiếng Việt ✓
    ↓
DB queries filter language: 'vi' ✓
```

---

## Files đã sửa

| File | Thay đổi |
|------|----------|
| `mobile/lib/src/data/local_database.dart` | Thêm `String language = 'en'` param vào 5 query methods: `nextNewWord`, `nextDueReviewWord`, `recentlyLearnedReviewWord`, `nextDifficultRelearnWord`, `countUnstudiedNewWords` |
| `mobile/lib/src/data/word_repository.dart` | Thêm `_activeLanguage` field + `setActiveLanguage()`. Truyền language vào `refillLearningCards`, `prefetchBatch`, `getNewWordWithFallbackResult`, `getReviewWord`, `getRecentReviewWordResult`, `getDifficultRelearnWord`, `fetchProficiency`, và 2 background operations |
| `mobile/lib/src/session/learning_session_controller.dart` | `setActiveLearningLanguage()` gọi `repository.setActiveLanguage()` + `showNewWord()` sau khi đổi. Tất cả repository calls nhận `language: _activeLearningLanguage` |

## Kết quả kiểm tra

- `dart analyze` trên 3 files: **No issues found** ✓
- `learning_session_controller_test.dart`: **10/10 tests passed** ✓
- `word_repository_test.dart`: đã có lỗi compile trước khi sửa (thiếu `scale` trong `ProficiencyState` và `defaultLearningLanguage` trong `AppConfig` — unrelated).
