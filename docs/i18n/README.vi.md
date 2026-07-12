# TC001 Codex Bridge for macOS

[← English](../../README.md) | [Hướng dẫn sử dụng đầy đủ](USAGE.vi.md)

## Tổng quan

TC001 Codex Bridge là ứng dụng macOS gốc hiển thị hạn mức Codex 5 giờ, 7 ngày và trạng thái làm việc trên Ulanzi TC001. Ứng dụng hỗ trợ AWTRIX qua HTTP và Bluetooth từ firmware đi kèm.

## Tính năng chính

Ứng dụng hiển thị hai thanh hạn mức, giá trị 5H/7D luân phiên và đèn trạng thái bốn màu. Bạn cũng có thể cấu hình trang giờ, ngày, nhiệt độ, độ ẩm và pin. Việc phân tích Codex diễn ra cục bộ trên Mac.

## Yêu cầu

Cần macOS 13 trở lên, Codex Desktop hoặc CLI đã đăng nhập và TC001 chạy AWTRIX 3. Bluetooth yêu cầu firmware awtrix3-ble.

## Bắt đầu nhanh

1. Chạy `./run-tests.sh` và `./build.sh`.
2. Mở `dist/TC001 Bridge.app` và cấp quyền Bluetooth cùng mạng cục bộ.
3. Chọn Tự động, Wi-Fi hoặc Bluetooth.

- Với Wi-Fi nhập IP hoặc `awtrix.local`; với Bluetooth chờ AWTRIX-BLE kết nối.
- Bật giám sát Codex tự động và thử các màu đèn.
- Cấu hình năm trang AWTRIX tích hợp khi cần.

## Quyền riêng tư và bảo mật

Không có telemetry hay máy chủ của dự án. Ứng dụng chỉ đọc trạng thái Codex cục bộ và gửi pixel đã dựng cùng cài đặt trang tới TC001. API cục bộ chỉ nghe tại 127.0.0.1 và từ chối yêu cầu có Origin trình duyệt.

## Giấy phép

Ứng dụng macOS dùng giấy phép MIT. Dự án không liên kết hoặc được OpenAI, Codex, Ulanzi, AWTRIX hay Blueforcer xác nhận.

[Giấy phép](../../LICENSE)
