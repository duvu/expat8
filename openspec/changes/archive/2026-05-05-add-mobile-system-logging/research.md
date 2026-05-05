## Kết quả nghiên cứu: Mobile system logging cho debug không cần emulator

### Mục tiêu nghiên cứu
- Xác định cách thu thập log đủ để trace lỗi trên máy thật, khi không kết nối emulator hoặc Flutter debugger.
- Xác định vị trí instrumentation có giá trị cao nhất trong codebase hiện tại.

### Quan sát từ hệ thống hiện tại
- App đã có xử lý fallback ở nhiều tầng (API -> repository -> controller) nhưng thiếu trace xuyên suốt cho cùng một sự kiện.
- Khi điều tra bằng logcat gần đây, phần lớn là log hệ thống; log đặc thù app chưa đủ để kết luận nguyên nhân lỗi nghiệp vụ.
- Các điểm dễ phát sinh lỗi nhất: gọi backend, sync queue, local SQLite, và điều phối learning session.

### Kết luận kỹ thuật
- Cần log có cấu trúc thay vì log text thuần để hỗ trợ lọc/tìm kiếm/tái dựng timeline.
- Cần lưu log cục bộ có retention để dùng được khi offline và sau khi app restart.
- Cần redaction trước khi persist để tránh tồn tại dữ liệu nhạy cảm trong thiết bị.
- Cần UI xem/export log trong app để user/operator trích xuất bằng máy thật.

### Phạm vi đề xuất
- Capability mới: `mobile-system-logging`.
- Capability sửa đổi: `mobile-local-cache-sync`, `mobile-learning-session`.
- Artifact specs/design/tasks đã được tạo trong change này để sẵn sàng implement.

### Rủi ro chính và hướng giảm thiểu
- Rủi ro hiệu năng I/O: áp dụng level policy + retention + ghi theo boundary.
- Rủi ro lộ dữ liệu: sanitizer bắt buộc + test redaction.
- Rủi ro log quá nhiều: filter theo category/level và mặc định ưu tiên warning/error.
