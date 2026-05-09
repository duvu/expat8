# Investigation: Swipe Phải→Trái Chỉ Load Được 3 Từ Mới

**Date:** 2026-05-09  
**Mode:** Explore only, no implementation

---

## Vấn đề

Người dùng swipe phải→trái nhưng chỉ nhận được tối đa **3 từ mới** liên tiếp, sau đó app hiển thị từ **review** thay vì từ mới. Yêu cầu thực tế: swipe phải→trái phải luôn luôn load từ mới từ local database, liên tục không giới hạn.

---

## Nguyên nhân gốc rễ

### Chuỗi gọi hiện tại

```
User swipe phải→trái
  └─ onSwipeRightToLeft()
       └─ _showSelectedCard(mode: _CardSelectionMode.mixed)
            └─ _selectionWindow.preferredKind()
                 └─ newCount < 3 ? CardKind.newWord : CardKind.review
```

### CardSelectionWindow — thủ phạm

File: `mobile/lib/src/session/card_selection.dart`

```dart
class CardSelectionWindow {
  CardSelectionWindow({this.windowSize = 20, this.targetNewCards = 3});

  CardKind preferredKind() {
    return newCount < targetNewCards ? CardKind.newWord : CardKind.review;
  }
  // ...
}
```

Window 20 thẻ, target 3 thẻ mới (15%). Sau khi đã hiển thị 3 từ mới, `preferredKind()` trả về `CardKind.review`. Swipe phải→trái lần thứ 4 trở đi sẽ nhận được review card.

### Mapping gesture → mode hiện tại

```
onSwipeRightToLeft() → mixed       ← VẤN ĐỀ: bị giới hạn bởi window
onSwipeLeftToRight() → reviewFirst
showNewWord()        → newFirst    ← Đây mới là "luôn luôn từ mới"
nextCard()           → mixed       ← Điều hướng sau rating
```

---

## Thiết kế gesture — mong muốn vs. thực tế

### Mong muốn

```
┌───────────────────────────────────────────────────────────────┐
│                    4 chiều swipe                              │
│                                                               │
│          Top→Bottom                                           │
│          [Khó / Cần học lại]                                  │
│                   │                                           │
│  Right→Left       │       Left→Right                          │
│  [Từ MỚI]  ──────[card]────── [Review]                        │
│  (liên tục)       │       (từ đã học)                         │
│                   │                                           │
│          Bottom→Top                                           │
│          [Đã nhớ / Dễ quá]                                    │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

Semantic rõ ràng: 4 hướng = 4 ý định khác nhau. Right→Left = "tôi muốn học từ mới".

### Thực tế hiện tại

```
Right→Left → "mixed" (3 từ mới rồi tự chuyển sang review)
           ≠ "Luôn luôn từ mới"
```

---

## Sự khác biệt giữa `mixed` và `newFirst`

| Mode | Hành vi | Dùng ở đâu |
|---|---|---|
| `mixed` | Theo window (≤3 từ mới trong 20 thẻ, rồi review) | `onSwipeRightToLeft`, `nextCard` |
| `newFirst` | Ưu tiên từ mới, fallback sang review nếu hết | `showNewWord()` |
| `reviewFirst` | Ưu tiên review, fallback sang từ mới nếu hết | `onSwipeLeftToRight` |

`_CardSelectionMode.newFirst` đã tồn tại và hoạt động đúng. `showNewWord()` dùng nó. Vấn đề chỉ là `onSwipeRightToLeft` không dùng nó.

---

## Tại sao `mixed` được thiết kế như vậy?

Ý định ban đầu: tránh "nhồi nhét" — nếu người dùng swipe liên tục, họ không nên nhận 20 từ mới liên tiếp mà không có review. Tỷ lệ 15% mới / 85% review giữ cân bằng học.

Nhưng logic này **phù hợp với `nextCard()` (điều hướng tự động sau rating), không phù hợp với `onSwipeRightToLeft()` (ý định rõ ràng của người dùng)**.

Khi người dùng chủ động swipe phải→trái, họ đang ra lệnh rõ ràng: "tôi muốn từ mới". Không nên override ý định này bằng window target.

---

## Behavior sau fix đơn giản

Nếu chỉ đổi `onSwipeRightToLeft` sang `newFirst`:

```
onSwipeRightToLeft() → newFirst  (luôn ưu tiên từ mới)
nextCard()           → mixed     (sau rating, giữ tỷ lệ cân bằng)
```

Điều này có nghĩa:
- Swipe phải→trái liên tục 100 lần → 100 từ mới (nếu local DB có đủ)
- Sau khi rating một thẻ, `nextCard()` vẫn dùng `mixed` để cân bằng
- `CardSelectionWindow` vẫn hoạt động cho luồng tự động, không bị xóa

---

## Fallback khi hết từ mới local

`newFirst` mode đã có fallback chain:

```
nextNewWord() → từ mới từ local DB
  ↓ không có
randomNotMasteredWord() → từ chưa mastered (đang học)
  ↓ không có
randomWord() → bất kỳ từ nào trong local DB
  ↓ không có
Empty state message
```

Fallback này đúng. Local DB không bao giờ block việc hiển thị thẻ — chỉ khi local DB thực sự trống mới hiện empty state.

---

## Rủi ro và câu hỏi mở

### Q1: `nextCard()` sau rating có nên đổi sang `newFirst` không?

Hiện tại `nextCard()` dùng `mixed`. Sau khi người dùng rating một từ và bấm tiếp theo, họ nhận thẻ theo tỷ lệ window. Điều này có thể OK — rating xong nên tiếp tục flow tự nhiên, không cần phải từ mới.

**Giữ nguyên `nextCard() → mixed` là hợp lý.**

### Q2: `CardSelectionWindow` còn có ích không?

Có, với `nextCard()` và điều hướng tự động. Nó không cần bị xóa hay thay đổi.

### Q3: Sau khi đổi, người dùng có thể "bị kẹt" trong luồng từ mới không?

Không. Left→Right vẫn là `reviewFirst`. Người dùng bao giờ cũng có thể swipe ngược để xem review.

---

## Bản đồ code cần thay đổi

Chỉ **1 dòng** thay đổi:

```dart
// File: mobile/lib/src/session/learning_session_controller.dart

// Hiện tại:
Future<void> onSwipeRightToLeft() async {
  await _showSelectedCard(mode: _CardSelectionMode.mixed);   // ← đây
}

// Sửa thành:
Future<void> onSwipeRightToLeft() async {
  await _showSelectedCard(mode: _CardSelectionMode.newFirst); // ← đây
}
```

---

## Phạm vi ảnh hưởng

| Thành phần | Thay đổi? |
|---|---|
| `card_selection.dart` | Không — `CardSelectionWindow` giữ nguyên |
| `learning_session_controller.dart` | Có — 1 dòng |
| `learning_screen.dart` | Không — wiring giữ nguyên |
| Backend | Không |
| Tests hiện có | Cần kiểm tra `onSwipeRightToLeft` test nếu có |

---

## Kết luận

Vấn đề không phải bug phức tạp — đây là **sai semantic mapping giữa gesture và selection mode**. Swipe phải→trái dùng `mixed` trong khi nên dùng `newFirst`. Một dòng thay đổi giải quyết toàn bộ vấn đề.

Nếu muốn implement: tạo OpenSpec change nhỏ hoặc fix trực tiếp sau khi thoát explore mode.
