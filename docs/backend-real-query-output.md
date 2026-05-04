# Backend Real Query Output

Generated at: 2026-05-04 (local)

## 1) Health

Command:

```bash
curl -sS http://localhost:8787/health
```

Output:

```json
{"ok":true}
```

## 2) Words Next (vi -> en)

Command:

```bash
curl -sS 'http://localhost:8787/v1/words/next?limit=5&source_language=vi&target_language=en'
```

Output:

```json
{"items":[{"server_word_id":"word_5ee57ae8-f50b-4ab9-8d86-656eaebf9730","term":"journey","language":"en","meaning_vi":"hành trình","part_of_speech":"noun","ipa":"/ˈdʒɜːrni/","vietnamese_pronunciation":"dơ-ni","example":"Her journey to learn English was full of surprises.","example_vi":"Hành trình học tiếng Anh của cô ấy đầy bất ngờ.","difficulty":"intermediate","topics":["travel","learning"],"created_at":"2026-05-04T13:28:20.969Z"},{"server_word_id":"word_6517aca3-f33e-465f-a6fe-5be23d0c3789","term":"challenge","language":"en","meaning_vi":"thử thách","part_of_speech":"noun","ipa":"/ˈtʃælɪndʒ/","vietnamese_pronunciation":"cha-leng","example":"He accepted the challenge and practiced every day.","example_vi":"Anh ấy đã chấp nhận thử thách và luyện tập mỗi ngày.","difficulty":"beginner","topics":["motivation","learning"],"created_at":"2026-05-04T13:28:20.989Z"},{"server_word_id":"word_bbf915f0-3bfd-4ac7-ac00-dce3162670b3","term":"imagine","language":"en","meaning_vi":"tưởng tượng","part_of_speech":"verb","ipa":"/ɪˈmædʒɪn/","vietnamese_pronunciation":"i-mê-djin","example":"Imagine a world where everyone can speak multiple languages.","example_vi":"Hãy tưởng tượng một thế giới nơi mọi người đều có thể nói nhiều ngôn ngữ.","difficulty":"intermediate","topics":["creative thinking","language"],"created_at":"2026-05-04T13:28:20.990Z"},{"server_word_id":"word_3beae56c-4a3b-430e-9887-835dbd53e883","term":"conversation","language":"en","meaning_vi":"cuộc trò chuyện","part_of_speech":"noun","ipa":"/ˌkɑːnvərˈseɪʃən/","vietnamese_pronunciation":"con-vờ-sei-sần","example":"Our conversation about books lasted for an hour.","example_vi":"Cuộc trò chuyện của chúng tôi về sách kéo dài một tiếng.","difficulty":"beginner","topics":["communication","speaking"],"created_at":"2026-05-04T13:28:20.991Z"},{"server_word_id":"word_ddf023a0-f5c2-442f-a3df-0dee4d57a152","term":"culture","language":"en","meaning_vi":"văn hóa","part_of_speech":"noun","ipa":"/ˈkʌltʃər/","vietnamese_pronunciation":"cân-chơ","example":"Traveling helps you understand the culture of other countries.","example_vi":"Du lịch giúp bạn hiểu văn hóa của các quốc gia khác.","difficulty":"beginner","topics":["travel","society"],"created_at":"2026-05-04T13:28:20.992Z"}]}
```

## 3) Words Recent (target vi)

Command:

```bash
curl -sS 'http://localhost:8787/v1/words/recent?limit=10&target_language=vi'
```

Output:

```json
{"items":[{"server_word_id":"word_799defea-4b9f-4490-b683-57c52d8dccc7","term":"làm ơn","language":"vi","meaning_vi":"Cách nói lịch sự để yêu cầu; tương đương 'please' hoặc 'please do me a favor'.","part_of_speech":"phrase","ipa":"/lam ən/","vietnamese_pronunciation":"làm ơn (lam on)","example":"'Làm ơn', could you open the window? is a polite way to ask for help.","example_vi":"'Làm ơn', bạn có thể mở cửa sổ không? là cách lịch sự để nhờ giúp.","difficulty":"beginner","topics":["politeness","requests"],"created_at":"2026-05-04T13:26:57.975Z"},{"server_word_id":"word_f6629378-2bea-4a1b-bab5-26c15a5f7835","term":"tạm biệt","language":"vi","meaning_vi":"Lời chào khi rời đi; tương đương 'goodbye' hoặc 'bye'.","part_of_speech":"phrase","ipa":"/tam biet/","vietnamese_pronunciation":"tạm biệt (tam biet)","example":"We hugged and said 'tạm biệt' before getting on the bus.","example_vi":"Chúng tôi ôm và nói 'tạm biệt' trước khi lên xe buýt.","difficulty":"beginner","topics":["greetings","farewells"],"created_at":"2026-05-04T13:26:57.974Z"},{"server_word_id":"word_a6ddcc14-65d8-4723-a536-19c4dc068e4d","term":"xin lỗi","language":"vi","meaning_vi":"Dùng để xin lỗi hoặc thu hút sự chú ý; tương đương 'sorry' hoặc 'excuse me'.","part_of_speech":"phrase","ipa":"/sin lɔj/","vietnamese_pronunciation":"xin lỗi (sin loi)","example":"If you step on someone's foot, quickly say 'xin lỗi'.","example_vi":"Nếu bạn giẫm lên chân ai đó, hãy nhanh chóng nói 'xin lỗi'.","difficulty":"beginner","topics":["politeness","apologizing"],"created_at":"2026-05-04T13:26:57.973Z"},{"server_word_id":"word_84eb7e8e-0aa8-4515-abd6-26b021b02707","term":"cảm ơn","language":"vi","meaning_vi":"Diễn tả sự biết ơn; tương đương 'thank you'.","part_of_speech":"phrase","ipa":"/kam ən/","vietnamese_pronunciation":"cảm ơn (cam on)","example":"After she handed me the book, I said 'cảm ơn'.","example_vi":"Sau khi cô ấy đưa sách cho tôi, tôi đã nói 'cảm ơn'.","difficulty":"beginner","topics":["politeness","basic expressions"],"created_at":"2026-05-04T13:26:57.972Z"},{"server_word_id":"word_83160e58-28cd-48d5-bc9f-eb5019c194c8","term":"xin chào","language":"vi","meaning_vi":"Lời chào thông thường; tương đương 'hello' hoặc 'hi'.","part_of_speech":"interjection","ipa":"/sin tɕaw/","vietnamese_pronunciation":"xin chào (sin chao)","example":"When you meet your neighbor, say 'xin chào' with a smile.","example_vi":"Khi gặp hàng xóm, hãy nói 'xin chào' kèm một nụ cười.","difficulty":"beginner","topics":["greetings","social"],"created_at":"2026-05-04T13:26:57.955Z"},{"server_word_id":"word_4f1b5418-e390-4ef3-a1cf-f6f4af38998e","term":"gia đình","language":"vi","meaning_vi":"family","part_of_speech":"noun","ipa":"/zaː ɗîŋ/","vietnamese_pronunciation":"gia đình","example":"Gia đình tôi có bốn người.","example_vi":"My family has four people.","difficulty":"beginner","topics":["people","relationships","home"],"created_at":"2026-05-04T13:25:35.005Z"},{"server_word_id":"word_ff0d6478-79f7-4a67-8b0f-436656cce774","term":"quyết định","language":"vi","meaning_vi":"to decide / decision","part_of_speech":"verb / noun","ipa":"/kwǐət dǐnˀ/","vietnamese_pronunciation":"quyết định","example":"Tôi đã quyết định đi du học.","example_vi":"I have decided to study abroad.","difficulty":"intermediate","topics":["actions","life events","work"],"created_at":"2026-05-04T13:25:35.003Z"},{"server_word_id":"word_a0065e7e-1932-4bf0-85fc-9c8a08236012","term":"thú vị","language":"vi","meaning_vi":"interesting / exciting","part_of_speech":"adjective","ipa":"/tʰǔ vîˀ/","vietnamese_pronunciation":"thú vị","example":"Cuốn sách này rất thú vị.","example_vi":"This book is very interesting.","difficulty":"beginner","topics":["feelings","entertainment","description"],"created_at":"2026-05-04T13:25:35.002Z"},{"server_word_id":"word_7f67f029-2e0a-400c-b2f2-72d0670a31ec","term":"môi trường","language":"vi","meaning_vi":"environment","part_of_speech":"noun","ipa":"/mōj ʈɨ̂əŋ/","vietnamese_pronunciation":"môi trường","example":"Chúng ta cần bảo vệ môi trường sống.","example_vi":"We need to protect the living environment.","difficulty":"intermediate","topics":["nature","ecology","society"],"created_at":"2026-05-04T13:25:35.000Z"},{"server_word_id":"word_0e4101a8-2855-4adf-a667-74bebf0d14fb","term":"phát triển","language":"vi","meaning_vi":"to develop","part_of_speech":"verb","ipa":"/fát ʈǐən/","vietnamese_pronunciation":"phát triển","example":"Công ty đang phát triển một ứng dụng mới.","example_vi":"The company is developing a new application.","difficulty":"intermediate","topics":["business","technology","growth"],"created_at":"2026-05-04T13:25:34.995Z"}]}
```

## 4) Study Events Sync

Command:

```bash
curl -sS -X POST 'http://localhost:8787/v1/study-events/sync' -H 'content-type: application/json' -d '{"device_id":"device_real_test","events":[{"client_event_id":"evt_real_20260504_1","server_word_id":"word_799defea-4b9f-4490-b683-57c52d8dccc7","local_word_id":"local_real_1","rating":"remembered","occurred_at":"2026-05-04T13:30:00.000Z"}]}'
```

Output:

```json
{"accepted_event_ids":["evt_real_20260504_1"],"rejected_events":[]}
```

## 5) Backend Logs (tail 80)

Command:

```bash
docker compose logs --tail=80 backend
```

Output:

```text
backend-1  | 
backend-1  | > expat8-language-backend@0.1.0 start
backend-1  | > node src/server.js
backend-1  | 
backend-1  | Expat8 backend listening on http://localhost:8787
backend-1  | ai_generation_item_rejected { reason: 'example_unrelated_to_term' }
backend-1  | ai_generation_item_rejected { reason: 'example_unrelated_to_term' }
backend-1  | ai_generation_item_rejected { reason: 'example_unrelated_to_term' }
backend-1  | ai_generation_item_rejected { reason: 'example_unrelated_to_term' }
backend-1  | ai_generation_item_rejected { reason: 'example_unrelated_to_term' }
backend-1  | ai_generation_item_rejected { reason: 'example_unrelated_to_term' }
backend-1  | ai_generation_item_rejected { reason: 'example_unrelated_to_term' }
backend-1  | ai_generation_item_rejected { reason: 'example_unrelated_to_term' }
backend-1  | ai_generation_item_rejected { reason: 'example_unrelated_to_term' }
backend-1  | ai_generation_item_rejected { reason: 'example_unrelated_to_term' }
backend-1  | ai_generation_item_rejected { reason: 'example_unrelated_to_term' }
backend-1  | ai_generation_item_rejected { reason: 'example_unrelated_to_term' }
backend-1  | ai_generation_item_rejected { reason: 'example_unrelated_to_term' }
```
