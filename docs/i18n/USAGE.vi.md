# TC001 Codex Bridge for macOS - Hướng dẫn sử dụng đầy đủ

[← README](README.vi.md) | [English usage guide](../USAGE.md)

## Cài đặt và kết nối

1. Chạy `./run-tests.sh` và `./build.sh`.
2. Mở `dist/TC001 Bridge.app` và cấp quyền Bluetooth cùng mạng cục bộ.
3. Chọn Tự động, Wi-Fi hoặc Bluetooth.
4. Với Wi-Fi nhập IP hoặc `awtrix.local`; với Bluetooth chờ AWTRIX-BLE kết nối.
5. Bật giám sát Codex tự động và thử các màu đèn.
6. Cấu hình năm trang AWTRIX tích hợp khi cần.

## Ý nghĩa hiển thị

Thanh 1x8 bên trái là hạn mức 5 giờ, bên phải là hạn mức 7 ngày. 5H hiển thị 7 giây và 7D 3 giây. Vàng là rảnh, xanh lá đang làm việc, xanh dương chờ xác nhận, đỏ là lỗi.

## Khắc phục sự cố

Nếu không thấy BLE, kiểm tra firmware 0.98-ble.4, quyền và ghép đôi cũ. Với Wi-Fi, xác nhận Mac truy cập được TC001. Nếu không có hạn mức, kiểm tra đăng nhập Codex và chờ làm mới.

## Quyền riêng tư và bảo mật

Không có telemetry hay máy chủ của dự án. Ứng dụng chỉ đọc trạng thái Codex cục bộ và gửi pixel đã dựng cùng cài đặt trang tới TC001. API cục bộ chỉ nghe tại 127.0.0.1 và từ chối yêu cầu có Origin trình duyệt.

## Giấy phép

Ứng dụng macOS dùng giấy phép MIT. Dự án không liên kết hoặc được OpenAI, Codex, Ulanzi, AWTRIX hay Blueforcer xác nhận.

[Giấy phép](../../LICENSE)
