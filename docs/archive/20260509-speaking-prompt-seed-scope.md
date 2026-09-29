# Speaking Prompt Seed Scope - Phase 0-3

## Scope Decision

The initial speaking foundation seed set targets **English-only A1-B1 prompts for Vietnamese learners**. The first production-ready set should contain 50-200 reviewed prompts before beta rollout.

Priority topics:

- Daily life and self-introduction.
- Work and meetings.
- Asking for help or clarification.
- Travel and services.
- Confidence-building short sentences using words already suitable for vocabulary cards.

Quality rules:

- A1-A2 prompts should be fewer than 12 words.
- Prompts must be natural spoken English, not essay-like examples.
- Each prompt should include a Vietnamese hint and one Vietnamese-specific pronunciation or usage note.
- Prompts should avoid sensitive personal, medical, financial, or political content.

## Initial 50-Prompt Target

| # | Target text | VI hint | Topic | Level |
|---|---|---|---|---|
| 1 | My name is Linh. | Ten toi la Linh. | self | A1 |
| 2 | I live in Hanoi. | Toi song o Ha Noi. | self | A1 |
| 3 | I work in marketing. | Toi lam marketing. | work | A1 |
| 4 | I need some help. | Toi can giup mot chut. | daily | A1 |
| 5 | Can you repeat that? | Ban noi lai duoc khong? | clarification | A1 |
| 6 | I do not understand. | Toi khong hieu. | clarification | A1 |
| 7 | Please speak more slowly. | Vui long noi cham hon. | clarification | A1 |
| 8 | I am learning English. | Toi dang hoc tieng Anh. | self | A1 |
| 9 | This is my first time. | Day la lan dau cua toi. | daily | A1 |
| 10 | I feel a little nervous. | Toi hoi lo lang. | confidence | A1 |
| 11 | The meeting starts at nine. | Cuoc hop bat dau luc 9 gio. | work | A2 |
| 12 | I have a quick question. | Toi co mot cau hoi nhanh. | work | A2 |
| 13 | Can we reschedule the meeting? | Minh doi lich hop duoc khong? | work | A2 |
| 14 | I will send it today. | Toi se gui no hom nay. | work | A2 |
| 15 | Let me check and reply. | De toi kiem tra va phan hoi. | work | A2 |
| 16 | I agree with this idea. | Toi dong y voi y nay. | work | A2 |
| 17 | I am not sure yet. | Toi chua chac lam. | work | A2 |
| 18 | Could you explain it again? | Ban giai thich lai duoc khong? | clarification | A2 |
| 19 | I need more time. | Toi can them thoi gian. | work | A2 |
| 20 | That sounds good to me. | Toi thay vay on. | work | A2 |
| 21 | She is a reliable teammate. | Co ay la dong doi dang tin cay. | work | B1 |
| 22 | I am getting used to this job. | Toi dang quen dan voi cong viec nay. | work | B1 |
| 23 | We should focus on one problem. | Chung ta nen tap trung vao mot van de. | work | B1 |
| 24 | I want to improve my speaking. | Toi muon cai thien ky nang noi. | learning | A2 |
| 25 | I made a small mistake. | Toi da mac mot loi nho. | confidence | A2 |
| 26 | It is okay to try again. | Thu lai cung khong sao. | confidence | A2 |
| 27 | I can say it more clearly. | Toi co the noi ro hon. | confidence | A2 |
| 28 | Could you give me an example? | Ban cho toi vi du duoc khong? | learning | A2 |
| 29 | I usually work from home. | Toi thuong lam viec tai nha. | work | A2 |
| 30 | I have a meeting this afternoon. | Chieu nay toi co mot cuoc hop. | work | A2 |
| 31 | Where is the nearest station? | Ga gan nhat o dau? | travel | A1 |
| 32 | I would like a coffee. | Toi muon mot ly ca phe. | service | A1 |
| 33 | How much does it cost? | Cai nay gia bao nhieu? | service | A1 |
| 34 | I booked a room online. | Toi da dat phong online. | travel | A2 |
| 35 | Can I pay by card? | Toi tra bang the duoc khong? | service | A1 |
| 36 | I am looking for this address. | Toi dang tim dia chi nay. | travel | A2 |
| 37 | I need to change my ticket. | Toi can doi ve. | travel | A2 |
| 38 | The food is really good. | Mon an rat ngon. | daily | A1 |
| 39 | I like this place. | Toi thich noi nay. | daily | A1 |
| 40 | I will be there soon. | Toi se den do som. | daily | A2 |
| 41 | I am available tomorrow morning. | Sang mai toi ranh. | work | A2 |
| 42 | Let us discuss this later. | Minh ban viec nay sau nhe. | work | A2 |
| 43 | I missed your message. | Toi da lo tin nhan cua ban. | daily | A2 |
| 44 | Thank you for your patience. | Cam on ban da kien nhan. | work | B1 |
| 45 | I need to practice every day. | Toi can luyen tap moi ngay. | learning | A2 |
| 46 | I spoke English for three minutes. | Toi da noi tieng Anh trong 3 phut. | learning | A2 |
| 47 | I feel more confident today. | Hom nay toi thay tu tin hon. | confidence | A2 |
| 48 | This sentence is hard for me. | Cau nay kho voi toi. | learning | A2 |
| 49 | I will try one more time. | Toi se thu them mot lan nua. | confidence | A2 |
| 50 | I am proud of my progress. | Toi tu hao ve tien bo cua minh. | confidence | B1 |

## Next Content Step

Before beta, each row should be expanded into reviewed prompt metadata:

- `target_phrase`
- `pronunciation_tip_vi`
- `common_mistake_vi`
- `word_sense_id` or seed vocabulary reference
- approval status
