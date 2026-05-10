## Context

`nextNewWord()` trong `LocalDatabase` query toàn bộ từ có status `newWord`, sort by `createdAtMs DESC`, và luôn trả về `rows.first`. Vì `showNewWord()` chỉ đọc từ mà không thay đổi status, mỗi lần swipe right-to-left đều nhận lại cùng một từ. Từ chỉ rời khỏi pool `newWord` sau khi user rating (swipe up/down), tạo ra trải nghiệm stuck.

## Goals / Non-Goals

**Goals:**
- Mỗi swipe right-to-left hiển thị một từ mới khác nhau.
- Từ khi được hiển thị lần đầu chuyển ngay sang `learning` (đúng với SRS model: new → learning → review → mastered).
- Không thay đổi SRS scheduling logic đã có (interval, nextReviewAtMs).

**Non-Goals:**
- Không thay đổi swipe up/down rating logic.
- Không thay đổi `nextDueReviewWord` hay review scheduling.
- Không thêm "undo" hoặc rollback khi từ được advance.

## Decisions

### D1: Advance `newWord` → `learning` khi hiển thị (không phải khi rating)

Khi `showNewWord()` hiển thị một từ có status `newWord`, ngay sau đó gọi `repository.markWordAsLearning(word, now)` để:
- Set `status = learning`
- Set `lastSeenAtMs = now`
- Set `nextReviewAtMs = now + 24h` (cùng interval với `markWordDifficultForRelearn`)

**Lý do**: Standard SRS model (Anki): từ mới chuyển sang learning ngay khi xem lần đầu. `nextNewWord()` sẽ không trả về cùng từ nữa vì status đã thay đổi.

**Alternative rejected**: Exclude `currentWord.localId` trong query — chỉ fix 1 swipe, không fix trường hợp restart app hoặc tab back.

### D2: `markWordAsLearning()` dùng interval 24h (giống markWordDifficultForRelearn)

Dùng 24h làm initial learning interval. Nếu user rate nó sau (swipe up = mastered, swipe down = relearn), scheduling cập nhật đè lên giá trị này. Behavior sau khi fix sẽ identical với flow hiện tại sau khi user đã rating.

### D3: Chỉ advance khi `actualKind == CardKind.newWord`

Không advance nếu `showNewWord()` fallback sang review word (đây là existing behavior, không thay đổi).

## Risks / Trade-offs

- [Risk]: Từ `newWord` chuyển sang `learning` khi xem lần đầu → ảnh hưởng count `countUnstudiedNewWords()`. **Mitigation**: Đây là đúng behavior, count unstudied new words sẽ giảm khi user thực sự học.
- [Risk]: Nếu prefetch chưa xong mà user đã swipe hết tất cả new words, `nextNewWord()` trả về null → fallback sang review. **Mitigation**: Prefetch threshold đã là 100, user khó swipe hết trước khi prefetch xong.
