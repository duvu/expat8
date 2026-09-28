# Word Blaster — Thiết kế game bắn từ vựng (GDD)

> Ngày: 2026-09-28 · Trạng thái: Đã lên kế hoạch (backlog: epic "Word Blaster" trên GitHub Issues)
> Engine: Flame 1.38 (đã dùng cho Sudoku, xem `mobile/lib/src/games/sudoku/sudoku_board_game.dart`)
> Liên quan: [Đề xuất tính năng tạo thói quen](../20260928-engagement-features-proposal.md), [Mobile guide — Offline Mode, Games](../mobile-guide.md)

## 1. Mục tiêu

Một game hành động ngắn (60–120 giây/ván) để **ôn từ vựng bằng phản xạ**, gắn trực tiếp vào vòng học của Expat8:

- Mỗi lần bắn đúng/sai là **một lượt ôn thật**: được ghi thành study event, đi vào SRS và đồng bộ khi có mạng.
- Chơi hoàn toàn **offline**, dùng kho từ đã có trên máy (seed bundle + từ đã học).
- Tạo lý do quay lại mỗi ngày (điểm cao, combo, bảng xếp hạng), **không** thay thế việc học: mọi phần thưởng dựa trên số từ trả lời đúng.

**Chỉ số thành công** (đo trong beta, 4 tuần):

| Chỉ số | Mục tiêu |
|---|---|
| Tỷ lệ người chơi ≥ 1 ván/tuần trong số người học hoạt động | ≥ 30% |
| Độ chính xác trung bình mỗi ván | 70–85% (không quá dễ, không quá khó) |
| Số từ được ôn qua game / người chơi / tuần | ≥ 40 |
| Tỷ lệ từ sai trong game được ôn lại trong 48h | ≥ 50% |
| FPS trên máy Android tầm thấp (4GB RAM) | ≥ 55 fps p95 |

## 2. Vòng chơi cốt lõi

```
Prompt hiện ở đáy màn hình  ──►  Các "thiên thạch" chứa đáp án rơi xuống  ──►  Chạm để bắn
(nghĩa tiếng Việt / audio /       (1 đúng + 2–4 nhiễu, cùng loại từ,          │
 câu ví dụ có chỗ trống)           cùng cấp độ, gần chính tả)                   ▼
                                                                     Đúng: nổ, +điểm, +combo,
                                                                     prompt mới
                                                                     Sai / để thiên thạch đúng
                                                                     chạm đáy: −1 mạng, hiện đáp
                                                                     án đúng 1.2s, reset combo
```

- **Điều khiển:** chạm vào thiên thạch → pháo ở đáy xoay và bắn (đạn bay ~0.15s, trúng mới tính). Một chạm = một phát; chạm liên tục vào nhiễu bị phạt.
- **Mạng:** 3 tim. Hết tim → kết thúc ván.
- **Wave:** mỗi 8 prompt là một wave; tốc độ rơi và số nhiễu tăng dần; wave 5, 10, … là **boss wave**.
- **Kết thúc ván:** màn tổng kết gồm điểm, độ chính xác, combo cao nhất, danh sách **từ sai** (bấm để nghe/xem ví dụ) và nút **"Ôn các từ sai"** (mở phiên học chỉ với các từ đó).

## 3. Chế độ chơi

| Chế độ | Prompt | Đáp án trên thiên thạch | Ghi chú |
|---|---|---|---|
| **Classic** | Nghĩa tiếng Việt | Từ tiếng Anh | Mặc định, 3 mạng, wave vô hạn |
| **Reverse** | Từ tiếng Anh (+IPA) | Nghĩa tiếng Việt | Cho người mới |
| **Listening** | Audio TTS (không hiện chữ) | Từ tiếng Anh | Nút nghe lại (tối đa 2 lần/prompt) |
| **Fill the gap** | Câu ví dụ có `___` (dùng `blankWord`) | Từ/cụm từ | Mở khi đạt level A2 |
| **Time Attack** | Như Classic | Như Classic | 60 giây, không mất mạng; sai −3s |

Ngôn ngữ học theo `activeLearningLanguage` (en/zh). Với tiếng Trung, Listening dùng `zh-CN` TTS, Reverse hiện pinyin (`vietnamesePronunciation`).

## 4. Chọn từ và tạo nhiễu

**Nguồn:** `VocabularyWord` trong ObjectBox (term, meaningVi, partOfSpeech, ipa, example, exampleVi, difficulty, topics, status, nextReviewAt, blankWord, entryType).

**Rổ từ mỗi ván** (40 từ, trộn theo tỷ lệ):

| Nhóm | Tỷ lệ | Truy vấn |
|---|---|---|
| Đến hạn ôn (SRS) | 50% | `status ∈ {learning, review}` và `nextReviewAt ≤ now` |
| Đã học gần đây / hay sai | 30% | `recentlyLearnedReviewWord`, `nextDifficultRelearnWord` |
| Từ mới đúng cấp độ | 20% | `status = newWord`, `difficulty ≤ proficiency + 1` |

Thiếu nhóm nào thì bù bằng nhóm khác. Tối thiểu cần **12 từ khả dụng**; ít hơn thì hiện màn "Học thêm vài từ để mở game" với nút mở màn học.

**Nhiễu** (2 ở wave 1–2, 3 ở wave 3–6, 4 từ wave 7):
1. Cùng `partOfSpeech` và cùng hoặc kề `difficulty`.
2. Ưu tiên gần chính tả (Levenshtein ≤ 3) hoặc cùng topic, để thử thách thật.
3. Không trùng nghĩa: loại nhiễu có `meaningVi` trùng hoặc chứa nghĩa đúng (so khớp chuỗi đã chuẩn hoá).
4. Không trùng đáp án đúng khác trên màn hình.

Bộ sinh câu hỏi là Dart thuần, có seed để test tất định.

## 5. Điểm, combo, vật phẩm, boss

- **Điểm:** `100 × hệ số combo × hệ số tốc độ`; hệ số tốc độ 1.0–1.5 theo độ cao thiên thạch lúc bắn (bắn sớm được nhiều hơn).
- **Combo:** mỗi câu đúng liên tiếp +1; hệ số x1 → x2 (5 combo) → x3 (10) → x4 (20). Sai hoặc để lọt → về x1.
- **Vật phẩm** (rơi ngẫu nhiên, tối đa 1 trên màn hình, chạm để lấy):
  - ❄️ **Làm chậm:** tốc độ ×0.5 trong 5s.
  - 💣 **Bom:** phá toàn bộ nhiễu đang rơi.
  - 🛡️ **Khiên:** chặn lần mất mạng kế tiếp.
  - ❤️ **Hồi mạng:** chỉ xuất hiện khi còn 1 tim.
- **Boss wave:** một "tàu mẹ" chứa **cụm từ/idiom** (`entryType ∈ {phrase, idiom}`); phải bắn đúng lần lượt 3 prompt liên quan để hạ. Hạ boss: +1000, hồi 1 tim.

## 6. Độ khó thích ứng

- Tốc độ rơi cơ bản theo cấp CEFR/HSK hiện tại của người học.
- Sau mỗi wave: độ chính xác ≥ 90% → tốc độ +8%; < 60% → −10% và giảm 1 nhiễu (tối thiểu 2).
- Luôn giữ thời gian tối thiểu 3.5s từ lúc thiên thạch xuất hiện đến lúc chạm đáy.

## 7. Gắn với việc học (quan trọng nhất)

| Sự kiện trong game | Ghi nhận học tập |
|---|---|
| Bắn đúng (nhanh hay chậm) | `StudyRating.easy` — tốc độ chỉ ảnh hưởng điểm, không ảnh hưởng SRS |
| Bắn sai / để lọt | `StudyRating.hard` cho từ đúng của prompt đó |
| Từ mới trả lời đúng lần đầu | Chuyển sang `learning` (như vuốt "learned") |

- Mỗi từ chỉ ghi **tối đa 1 study event mỗi ván** (lần đầu gặp), để game không làm méo SRS.
- Study event dùng `WordRepository` (cùng hàng đợi offline, có `language`), gắn `source: "game_word_blaster"` trong payload để phân tích sau (backend bỏ qua field lạ, cần xác nhận trong hợp đồng API).
- Cấp độ proficiency vẫn chỉ đổi theo luật hiện có (5 lần `too_easy`/`hard` liên tiếp); game **không** gửi `too_easy`/`too_hard`.

## 8. Bảng xếp hạng và thống kê

- Dùng chung lớp lưu trữ game (tách từ `SudokuChampionStore` thành `GameScoreStore` tổng quát): top 10 mỗi chế độ, tên người chơi, điểm, độ chính xác, combo cao nhất, ngày.
- Thống kê: số ván, tổng từ đúng, độ chính xác 7 ngày, từ hay sai nhất (top 10).
- Giai đoạn sau (P2): bảng xếp hạng toàn cầu tuần qua backend, chỉ dành cho tài khoản đăng nhập.

## 9. Hình ảnh, âm thanh, cảm giác

- Phong cách: vũ trụ phẳng (flat) theo màu Material của app, hỗ trợ sáng/tối; thiên thạch là "viên đá" bo tròn chứa chữ, chữ luôn ≥ 16sp.
- Hiệu ứng Flame: particle nổ, trail đạn, rung màn hình nhẹ khi mất mạng, số điểm bay lên, nền parallax sao 2–3 lớp.
- Âm thanh (`flame_audio`): bắn, trúng, sai, combo lên cấp, boss, nhạc nền lặp. Chỉ dùng asset có giấy phép thương mại (CC0/mua bản quyền), ghi nguồn trong `assets/audio/LICENSES.md`.
- Rung phản hồi (haptics) khi trúng/sai.
- Cài đặt: âm thanh, nhạc, rung, **giảm chuyển động** (tắt shake/particle lớn, tốc độ −20%).
- Trợ năng: prompt và đáp án có Semantics; chế độ màu an toàn cho người mù màu (không dùng đỏ/xanh làm tín hiệu duy nhất).

## 10. Kiến trúc kỹ thuật

```
mobile/lib/src/games/
  common/                      ← dùng chung cho mọi game
    game_score_store.dart        (top-10 theo game + chế độ, tách từ Sudoku)
    game_settings.dart           (âm thanh/nhạc/rung/giảm chuyển động)
    game_audio.dart              (flame_audio wrapper, tắt được)
  word_blaster/
    word_pool.dart               (chọn rổ từ theo SRS, Dart thuần)
    question_generator.dart      (prompt + nhiễu, có seed)
    word_blaster_session.dart    (luật: mạng, điểm, combo, wave, vật phẩm; ChangeNotifier + feedback stream như Sudoku)
    word_blaster_learning.dart   (ghi study event qua WordRepository, mỗi từ ≤1/ván)
    game/                        (Flame: WordBlasterGame, MeteorComponent, CannonComponent,
                                  ProjectileComponent, PowerUpComponent, BossComponent,
                                  StarfieldParallax, effects)
    ui/                          (home, HUD overlay, pause, game over + recap, champion board)
```

Nguyên tắc (giống Sudoku): **luật chơi ở Dart thuần, test được không cần engine**; Flame chỉ vẽ và tạo hiệu ứng; HUD/menus là widget Flutter qua `overlays` của `GameWidget`.

## 11. Ngoài phạm vi (giai đoạn này)

Chơi nhiều người thời gian thực, mua vật phẩm bằng tiền, nhận diện giọng nói trong game, tạo level do người dùng.

## 12. Rủi ro

| Rủi ro | Giảm thiểu |
|---|---|
| Game làm méo SRS (ôn quá nhiều/đoán mò) | ≤1 event/từ/ván; phạt bắn bừa; chỉ `easy`/`hard` |
| Nhiễu có nghĩa gần như đáp án → người học bị phạt oan | Lọc trùng nghĩa; báo cáo "câu hỏi sai" từ màn tổng kết |
| Hiệu năng máy yếu | Pool component, giới hạn particle, test trên máy tầm thấp |
| Kho từ quá ít khi mới cài | Tối thiểu 12 từ; seed bundle có 100 từ/ngôn ngữ |
| Asset âm thanh vi phạm bản quyền | Chỉ CC0/đã mua, có file LICENSES |
