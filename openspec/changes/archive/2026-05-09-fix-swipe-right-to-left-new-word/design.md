## Context

`_showSelectedCard` nhận một `_CardSelectionMode` enum để quyết định loại thẻ ưu tiên:

```
mixed       → _selectionWindow.preferredKind() (window-based, ≤3 new / 20)
newFirst    → luôn CardKind.newWord, fallback chain nếu hết
reviewFirst → luôn CardKind.review, fallback sang new nếu hết
```

Hiện tại `onSwipeRightToLeft` dùng `mixed` giống `nextCard()`. Đây là nguyên nhân gây giới hạn 3 lần.

## Goals / Non-Goals

**Goals:**
- Swipe phải→trái luôn hiển thị từ mới (newFirst), không bị window giới hạn
- Fallback chain (`randomNotMasteredWord` → `randomWord`) vẫn hoạt động khi local DB hết từ mới
- `nextCard()` (post-rating navigation) giữ nguyên `mixed` để tỷ lệ 15%/85% vẫn đúng trong luồng tự động

**Non-Goals:**
- Không xóa `CardSelectionWindow` hay `mixed` mode — chúng vẫn cần cho `nextCard()`
- Không thay đổi left-to-right, top-to-bottom, bottom-to-top gestures
- Không thay đổi backend hay refill logic

## Decisions

**Chỉ đổi mode của `onSwipeRightToLeft`, không đổi `nextCard()`**

`nextCard()` là điều hướng tự động sau khi rating. Việc giữ `mixed` ở đây đảm bảo người dùng không bị "nhồi" toàn từ mới khi học theo luồng thông thường. Right-to-left swipe là gesture chủ động của người dùng — semantic rõ ràng là "tôi muốn từ mới" nên không cần window target.

**Không đổi fallback chain**

`newFirst` đã có fallback chain đúng: `nextNewWord → randomNotMasteredWord → randomWord → empty`. Không cần thay đổi gì thêm.

## Risks / Trade-offs

- **Rủi ro thấp**: Đây là 1 dòng thay đổi, `newFirst` mode đã hoạt động ổn định qua `showNewWord()`
- **Trade-off**: Người dùng có thể "mắc kẹt" với từ mới liên tục nếu họ swipe phải→trái không nghỉ. Nhưng đây là ý định của họ, và left-to-right luôn sẵn để xem review
- **Không breaking**: `CardSelectionWindow` không bị thay đổi; các code path khác giữ nguyên
