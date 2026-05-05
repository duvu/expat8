## Context

Ứng dụng mobile hiện tại có logging rải rác qua console và phụ thuộc mạnh vào môi trường debug kết nối trực tiếp (emulator/logcat/Flutter attach). Khi chạy trên máy thật hoặc khi người dùng báo lỗi từ xa, team không có đủ dữ liệu để tái hiện chuỗi sự kiện gây lỗi.

Kết quả nghiên cứu nhanh trên codebase hiện tại:
- Lỗi nghiệp vụ chính tập trung ở các luồng: gọi backend, đồng bộ event queue, truy cập SQLite, và điều phối learning session.
- Các lỗi này hiện được bắt và chuyển thành fallback UX, nhưng thiếu trace xuyên suốt giữa các tầng (UI -> repository -> API/local DB).
- Trong thực tế debug gần nhất, logcat cho thấy ít lỗi đặc thù app; vì vậy cần log ứng dụng có cấu trúc, tự lưu trên thiết bị và có thể xuất ra ngoài.

Ràng buộc:
- Không được ghi lộ dữ liệu nhạy cảm (`APP_CREDENTIAL_SECRET`, bearer token, mật khẩu, payload chứa secret).
- Ghi log phải nhẹ, không làm chậm luồng học từ vựng.
- Cần dùng được cả online/offline.

## Goals / Non-Goals

**Goals:**
- Xây dựng logging subsystem trên mobile với schema thống nhất: `timestamp`, `level`, `category`, `event`, `message`, `context`, `traceId`.
- Ghi log cho các thành phần trọng yếu: API client, sync worker, local DB, controller/session.
- Lưu log cục bộ có retention (theo số lượng + thời gian) và cơ chế rotation.
- Cung cấp giao diện xem/lọc log và export log ra file chia sẻ để debug từ thiết bị thật.
- Áp dụng redaction tự động trước khi persist/export.

**Non-Goals:**
- Không xây hệ thống quan sát realtime server-side trong thay đổi này.
- Không thay đổi giao thức API backend chỉ để phục vụ logging.
- Không thay thế toàn bộ analytics hiện có; chỉ tập trung vào debug/trace vận hành.

## Decisions

1. Logging domain model chuẩn hóa
- Quyết định: định nghĩa `LogEntry` bất biến với metadata bắt buộc và `context` dạng key-value JSON an toàn.
- Lý do: cho phép truy vấn/lọc và tái dựng timeline sự cố nhất quán.
- Phương án thay thế đã cân nhắc: log chuỗi text thuần; bị loại vì khó lọc, khó redact nhất quán.

2. Log sink cục bộ qua SQLite
- Quyết định: thêm bảng log vào local database thay vì ghi file text trực tiếp.
- Lý do: đã có hạ tầng SQLite, truy vấn/lọc/paginate tốt, dễ retention bằng SQL delete theo điều kiện.
- Phương án thay thế: rolling text file; bị loại vì lọc phức tạp và dễ lỗi đồng bộ khi concurrent writes.

3. Redaction-first pipeline
- Quyết định: mọi log đi qua `LogSanitizer` trước khi lưu hoặc export.
- Lý do: giảm rủi ro lộ token/secret từ request headers hoặc exception message.
- Phương án thay thế: redact khi export; bị loại vì dữ liệu nhạy cảm vẫn tồn tại trong store.

4. Instrumentation theo boundary
- Quyết định: đặt điểm ghi log tại biên kiến trúc (API, repository, DB, sync worker, controller), không log tràn lan trong mọi method nhỏ.
- Lý do: giữ signal-to-noise tốt, giảm overhead, dễ truy vết theo event business.
- Phương án thay thế: log tất cả hàm; bị loại vì noisy, tốn dung lượng và khó dùng.

5. In-app log viewer và export
- Quyết định: thêm màn hình debug logs trong drawer/settings với filter level/category/date và nút export.
- Lý do: hỗ trợ vận hành khi không có emulator hoặc remote debugger.
- Phương án thay thế: chỉ lưu local không UI; bị loại vì khó lấy log từ user cuối.

## Risks / Trade-offs

- [Tăng I/O ghi log] -> Mitigation: batch write nhẹ, giới hạn tần suất log debug, retention cứng theo số bản ghi.
- [Log quá nhiều làm khó đọc] -> Mitigation: định nghĩa category chuẩn và level policy; mặc định hiển thị warning/error.
- [Lộ dữ liệu nhạy cảm] -> Mitigation: redaction bắt buộc + test snapshot cho sanitizer + denylist key patterns.
- [Ảnh hưởng UX khi export file lớn] -> Mitigation: export theo khoảng thời gian và nén JSONL khi vượt ngưỡng.
- [Sai lệch timestamp khi timezone/thời gian máy thay đổi] -> Mitigation: lưu UTC ISO8601 + monotonic sequence id cục bộ.

## Migration Plan

1. Thêm schema/bảng log trong local DB với migration version mới.
2. Triển khai `Logger`, `LogStore`, `LogSanitizer`, và wire dependency vào repository/controller/api client/sync worker.
3. Bật logging theo level mặc định (`info` trở lên trong production; `debug` khi bật cờ debug nội bộ).
4. Thêm màn hình xem/export log và kiểm thử end-to-end luồng export trên máy thật.
5. Rollback: tắt feature flag logging UI + giảm level xuống `error`; migration DB giữ tương thích ngược (không phá dữ liệu hiện hữu).

## Open Questions

- Có cần upload log tự động lên backend trong release sau (opt-in theo user consent) hay chỉ manual export?
- Nên dùng JSONL hay CSV làm định dạng export mặc định cho team vận hành?
- Cần giữ log tối đa bao nhiêu ngày để cân bằng dung lượng và khả năng điều tra?
