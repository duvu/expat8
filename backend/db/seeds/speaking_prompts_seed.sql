-- Seed: 50 curated speaking prompts (A1-B1 level, work/daily/travel topics)
-- word_sense_id is NULL for general-practice prompts not tied to a specific word sense.
-- Apply after 20260510_speaking_drill_completed.sql migration.

INSERT INTO speaking_prompts (id, word_sense_id, target_text, vi_hint, pronunciation_tip_vi, common_mistake_vi, difficulty, topic, status, created_at, updated_at)
VALUES

-- A1 – Daily
('sp_seed_001', NULL, 'My name is David.', 'Tên tôi là David.', 'Nhấn "name" và "David" mạnh hơn', 'Đừng nói "My name David" (thiếu "is")', 'A1', 'daily', 'approved', now(), now()),
('sp_seed_002', NULL, 'I am from Vietnam.', 'Tôi đến từ Việt Nam.', '"from" phát âm /frɒm/', 'Đừng nói "I am from the Vietnam"', 'A1', 'daily', 'approved', now(), now()),
('sp_seed_003', NULL, 'How are you today?', 'Hôm nay bạn có khỏe không?', 'Lên giọng ở cuối câu hỏi', 'Đừng nói "How are you now" trong tình huống gặp mặt', 'A1', 'daily', 'approved', now(), now()),
('sp_seed_004', NULL, 'Nice to meet you.', 'Rất vui được gặp bạn.', '"meet" phát âm /miːt/', 'Đừng nói "Nice meet you"', 'A1', 'daily', 'approved', now(), now()),
('sp_seed_005', NULL, 'I live in Hanoi.', 'Tôi sống ở Hà Nội.', '"live" /lɪv/ – không phải /laɪv/', 'Đừng nhầm "live" (verb) với "live" (adj)', 'A1', 'daily', 'approved', now(), now()),
('sp_seed_006', NULL, 'I have two sisters.', 'Tôi có hai chị gái.', '"sisters" – nhấn vần đầu /ˈsɪstəz/', 'Đừng bỏ "have" – không nói "I two sisters"', 'A1', 'daily', 'approved', now(), now()),
('sp_seed_007', NULL, 'What time is it?', 'Mấy giờ rồi?', 'Giọng hơi lên ở "time"', 'Đừng nói "What time it is?" trong câu hỏi trực tiếp', 'A1', 'daily', 'approved', now(), now()),
('sp_seed_008', NULL, 'I like coffee in the morning.', 'Tôi thích cà phê vào buổi sáng.', '"morning" nhấn âm đầu /ˈmɔːrnɪŋ/', 'Đừng nói "in morning" (cần mạo từ "the")', 'A1', 'daily', 'approved', now(), now()),
('sp_seed_009', NULL, 'Can you help me, please?', 'Bạn có thể giúp tôi được không?', '"please" thêm vào cuối để lịch sự', 'Đừng quên "please" – nghe lịch sự hơn nhiều', 'A1', 'daily', 'approved', now(), now()),
('sp_seed_010', NULL, 'I don''t understand.', 'Tôi không hiểu.', '"understand" – nhấn âm cuối /ˌʌndəˈstænd/', 'Đừng nói "I no understand"', 'A1', 'daily', 'approved', now(), now()),

-- A1 – Work
('sp_seed_011', NULL, 'I am a software engineer.', 'Tôi là kỹ sư phần mềm.', '"engineer" /ˌendʒɪˈnɪər/ – nhấn âm cuối', 'Đừng nói "I am software engineer" (thiếu "a")', 'A1', 'work', 'approved', now(), now()),
('sp_seed_012', NULL, 'I work at a tech company.', 'Tôi làm việc ở một công ty công nghệ.', '"work at" – giới từ "at" dùng cho địa điểm', 'Đừng nói "work in a tech company"', 'A1', 'work', 'approved', now(), now()),
('sp_seed_013', NULL, 'The meeting starts at nine.', 'Cuộc họp bắt đầu lúc chín giờ.', '"starts" – âm "s" ở cuối', 'Đừng nói "meeting start" (thiếu "s")', 'A1', 'work', 'approved', now(), now()),
('sp_seed_014', NULL, 'I send emails every day.', 'Tôi gửi email mỗi ngày.', '"every day" – hai từ riêng biệt', 'Đừng nói "everyday" (adj, không phải "mỗi ngày")', 'A1', 'work', 'approved', now(), now()),
('sp_seed_015', NULL, 'My office is on the third floor.', 'Văn phòng của tôi ở tầng ba.', '"third" /θɜːd/ – âm "th" nhẹ', 'Đừng nói "in the third floor" (dùng "on")', 'A1', 'work', 'approved', now(), now()),

-- A1 – Travel
('sp_seed_016', NULL, 'Where is the train station?', 'Ga tàu ở đâu?', '"station" /ˈsteɪʃən/ – nhấn âm đầu', 'Đừng nói "Where train station is?" trong câu hỏi trực tiếp', 'A1', 'travel', 'approved', now(), now()),
('sp_seed_017', NULL, 'I need a taxi, please.', 'Tôi cần một chiếc taxi, làm ơn.', '"taxi" /ˈtæksi/ – nhấn âm đầu', 'Đừng quên "please" để thêm lịch sự', 'A1', 'travel', 'approved', now(), now()),
('sp_seed_018', NULL, 'One ticket to Danang, please.', 'Một vé đến Đà Nẵng, xin vui lòng.', '"ticket" /ˈtɪkɪt/ – "t" cuối giữ nhẹ', 'Đừng nói "a ticket" khi đã có số đếm "one"', 'A1', 'travel', 'approved', now(), now()),
('sp_seed_019', NULL, 'Is this the right bus?', 'Đây có phải xe buýt đúng không?', '"right" ở đây nghĩa là "đúng/phải"', 'Đừng nhầm "right" (đúng) với "right" (phải/bên phải)', 'A1', 'travel', 'approved', now(), now()),
('sp_seed_020', NULL, 'How far is the hotel?', 'Khách sạn cách đây bao xa?', '"far" /fɑːr/ – phát âm rõ âm "r"', 'Đừng nói "How far the hotel is?" trong câu hỏi', 'A1', 'travel', 'approved', now(), now()),

-- A2 – Daily
('sp_seed_021', NULL, 'I usually wake up at six thirty.', 'Tôi thường thức dậy lúc sáu rưỡi.', '"usually" /ˈjuːʒuəli/ – hay bị nuốt âm', 'Đừng nói "I use to wake up" (sai cấu trúc)', 'A2', 'daily', 'approved', now(), now()),
('sp_seed_022', NULL, 'We are having dinner together tonight.', 'Tối nay chúng tôi ăn tối cùng nhau.', '"together" nhấn âm giữa /təˈɡeðər/', 'Đừng dùng simple present: "We have dinner tonight"', 'A2', 'daily', 'approved', now(), now()),
('sp_seed_023', NULL, 'I enjoy listening to podcasts.', 'Tôi thích nghe podcast.', '"enjoy" + V-ing (không dùng to-inf)', 'Đừng nói "I enjoy to listen"', 'A2', 'daily', 'approved', now(), now()),
('sp_seed_024', NULL, 'Could you speak more slowly, please?', 'Bạn có thể nói chậm hơn được không?', '"slowly" /ˈsləʊli/ – trạng từ, không dùng "slow"', 'Đừng nói "speak more slow"', 'A2', 'daily', 'approved', now(), now()),
('sp_seed_025', NULL, 'I haven''t eaten yet.', 'Tôi chưa ăn gì.', '"haven''t" /ˈhævnt/ – thu gọn tự nhiên', 'Đừng nói "I didn''t eat yet" (dùng perfect cho "yet")', 'A2', 'daily', 'approved', now(), now()),

-- A2 – Work
('sp_seed_026', NULL, 'Can we reschedule the meeting?', 'Chúng ta có thể dời lịch họp không?', '"reschedule" /ˌriːˈʃedjuːl/ – nhấn âm thứ hai', 'Đừng nói "change the meeting time" – "reschedule" chuyên nghiệp hơn', 'A2', 'work', 'approved', now(), now()),
('sp_seed_027', NULL, 'I will send you the report by Friday.', 'Tôi sẽ gửi báo cáo cho bạn trước thứ Sáu.', '"by Friday" = trước hoặc vào thứ Sáu', 'Đừng nói "until Friday" (until = kéo dài đến)', 'A2', 'work', 'approved', now(), now()),
('sp_seed_028', NULL, 'Could you clarify what you mean?', 'Bạn có thể làm rõ ý của mình không?', '"clarify" /ˈklærɪfaɪ/ – nhấn âm đầu', 'Đừng nói "Could you clear what you mean"', 'A2', 'work', 'approved', now(), now()),
('sp_seed_029', NULL, 'I am working on this task right now.', 'Tôi đang làm nhiệm vụ này ngay lúc này.', '"right now" nhấn để thể hiện đang bận', 'Đừng dùng simple present: "I work on this task"', 'A2', 'work', 'approved', now(), now()),
('sp_seed_030', NULL, 'Let me know if you need anything.', 'Cho tôi biết nếu bạn cần gì.', '"let me know" – cụm lịch sự phổ biến', 'Đừng nói "Tell me if you need anything" – nghe cứng hơn', 'A2', 'work', 'approved', now(), now()),

-- A2 – Travel
('sp_seed_031', NULL, 'I would like to check in, please.', 'Tôi muốn làm thủ tục nhận phòng.', '"check in" – verb, "check-in" – noun', 'Đừng nói "I want check in" (cần "would like to")', 'A2', 'travel', 'approved', now(), now()),
('sp_seed_032', NULL, 'Do you have a room available?', 'Bạn có phòng trống không?', '"available" /əˈveɪləbl/ – nhấn âm thứ hai', 'Đừng nói "Do you have a free room?" (less formal)', 'A2', 'travel', 'approved', now(), now()),
('sp_seed_033', NULL, 'Could I get a window seat, please?', 'Tôi có thể có ghế cạnh cửa sổ không?', '"window seat" – hai từ, không gộp', 'Đừng nói "Can I get a seat near window"', 'A2', 'travel', 'approved', now(), now()),
('sp_seed_034', NULL, 'I need to exchange some money.', 'Tôi cần đổi một ít tiền.', '"exchange" /ɪkˈstʃeɪndʒ/ – nhấn âm thứ hai', 'Đừng nói "change money" trong ngữ cảnh ngân hàng – dùng "exchange"', 'A2', 'travel', 'approved', now(), now()),
('sp_seed_035', NULL, 'What time does the tour start?', 'Tour bắt đầu lúc mấy giờ?', '"tour" /tʊər/ – một âm tiết', 'Đừng hỏi "What time the tour starts?" trong câu hỏi trực tiếp', 'A2', 'travel', 'approved', now(), now()),

-- B1 – Daily
('sp_seed_036', NULL, 'I have been learning English for two years.', 'Tôi đã học tiếng Anh được hai năm.', '"have been learning" – hiện tại hoàn thành tiếp diễn', 'Đừng nói "I am learning English for two years"', 'B1', 'daily', 'approved', now(), now()),
('sp_seed_037', NULL, 'If I had more time, I would read more books.', 'Nếu có nhiều thời gian hơn, tôi sẽ đọc nhiều sách hơn.', 'Câu điều kiện loại 2 – if + past simple, would + bare inf', 'Đừng nói "If I will have more time"', 'B1', 'daily', 'approved', now(), now()),
('sp_seed_038', NULL, 'I should have called you earlier.', 'Lẽ ra tôi nên gọi cho bạn sớm hơn.', '"should have" + past participle = tiếc nuối về quá khứ', 'Đừng nói "I should call you earlier"', 'B1', 'daily', 'approved', now(), now()),
('sp_seed_039', NULL, 'She tends to arrive late on Mondays.', 'Cô ấy có xu hướng đến trễ vào thứ Hai.', '"tend to" + base verb – thể hiện xu hướng', 'Đừng nói "She tends arriving" (cần to-inf)', 'B1', 'daily', 'approved', now(), now()),
('sp_seed_040', NULL, 'It depends on how much time we have.', 'Điều đó phụ thuộc vào chúng ta có bao nhiêu thời gian.', '"depend on" – luôn dùng giới từ "on"', 'Đừng nói "It depends of" hoặc "It depends"', 'B1', 'daily', 'approved', now(), now()),

-- B1 – Work
('sp_seed_041', NULL, 'Could you walk me through the process?', 'Bạn có thể giải thích từng bước của quy trình cho tôi không?', '"walk someone through" = giải thích chi tiết từng bước', 'Đừng nói "Could you explain me the process"', 'B1', 'work', 'approved', now(), now()),
('sp_seed_042', NULL, 'We need to align on the project goals.', 'Chúng ta cần thống nhất về mục tiêu dự án.', '"align on" – cụm từ phổ biến trong môi trường công nghệ', 'Đừng nói "agree the goals" (thiếu giới từ)', 'B1', 'work', 'approved', now(), now()),
('sp_seed_043', NULL, 'I would appreciate your feedback on this.', 'Tôi rất trân trọng phản hồi của bạn về vấn đề này.', '"appreciate" + noun/gerund – lịch sự, chuyên nghiệp', 'Đừng nói "I appreciate if you give feedback"', 'B1', 'work', 'approved', now(), now()),
('sp_seed_044', NULL, 'Let''s take this offline after the call.', 'Hãy thảo luận riêng sau cuộc gọi này.', '"take offline" – jargon: chuyển sang thảo luận riêng', 'Đừng dịch sát nghĩa – "offline" ở đây không liên quan mạng', 'B1', 'work', 'approved', now(), now()),
('sp_seed_045', NULL, 'I''m a bit swamped this week, but I''ll manage.', 'Tuần này tôi khá bận, nhưng tôi sẽ xoay xở được.', '"swamped" = overwhelmed with work (informal)', 'Đừng nói "I am drowned in work" – không phải idiom thông dụng', 'B1', 'work', 'approved', now(), now()),

-- B1 – Travel
('sp_seed_046', NULL, 'I''d like to report a lost passport.', 'Tôi muốn trình báo về hộ chiếu bị mất.', '"report" + noun = trình báo chính thức', 'Đừng nói "I want to say about lost passport"', 'B1', 'travel', 'approved', now(), now()),
('sp_seed_047', NULL, 'Could you recommend a good local restaurant?', 'Bạn có thể giới thiệu một nhà hàng địa phương ngon không?', '"recommend" + noun/that-clause/gerund', 'Đừng nói "Could you suggest me a restaurant"', 'B1', 'travel', 'approved', now(), now()),
('sp_seed_048', NULL, 'I''m not sure what the baggage allowance is.', 'Tôi không chắc quy định về hành lý ký gửi là gì.', '"baggage allowance" – lượng hành lý được phép', 'Đừng nói "baggage limit" – "allowance" phổ biến hơn trong ngành hàng không', 'B1', 'travel', 'approved', now(), now()),
('sp_seed_049', NULL, 'Is the Wi-Fi included in the room rate?', 'Wi-Fi có được bao gồm trong giá phòng không?', '"included in" – giới từ đúng trong ngữ cảnh này', 'Đừng nói "Is Wi-Fi free?" – câu trên formal hơn khi check-in', 'B1', 'travel', 'approved', now(), now()),
('sp_seed_050', NULL, 'We arrived earlier than expected due to good traffic.', 'Chúng tôi đến sớm hơn dự kiến nhờ giao thông thuận lợi.', '"due to" = because of (formal, viết đứng sau động từ)', 'Đừng nói "because of good traffic" – cả hai đúng, nhưng "due to" lịch sự hơn', 'B1', 'travel', 'approved', now(), now())

ON CONFLICT (id) DO NOTHING;
