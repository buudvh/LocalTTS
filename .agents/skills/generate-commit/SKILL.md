---
name: generate-commit
description: Hướng dẫn tạo nội dung commit (commit message) chi tiết bằng tiếng Việt dựa trên thay đổi mã nguồn trong dự án.
---

# Hướng dẫn Tạo Nội dung Commit bằng Tiếng Việt (Git Commit Message)

Sử dụng skill này khi người dùng yêu cầu tạo nội dung commit cho các thay đổi hiện tại trong mã nguồn để họ tự thực hiện lệnh commit.

## Quy trình Thực hiện

### 1. Phân tích các thay đổi hiện tại
- Sử dụng lệnh `git status` và `git diff` (hoặc `git diff --cached` nếu các tệp đã được đưa vào stage) để phân tích các tệp tin bị thay đổi, thêm mới hoặc xóa bỏ.
- Xác định mục đích chính của các thay đổi (sửa lỗi, thêm tính năng mới, tái cấu trúc mã nguồn, tối ưu hóa hiệu năng, cập nhật tài liệu, cập nhật cấu hình dự án).

### 2. Định dạng nội dung commit
Nội dung commit cần tuân thủ cấu trúc Conventional Commits chuẩn hóa nhưng viết bằng tiếng Việt:

```text
<kiểu_commit>(<phạm_vi_nếu_có>): <tóm_tắt_ngắn_gọn_không_dấu_chấm_cuối>

- Chi tiết thay đổi thứ nhất (bắt đầu bằng động từ dạng hành động, ví dụ: Thêm, Sửa, Xóa, Cập nhật, Tối ưu).
- Chi tiết thay đổi thứ hai.
- Chi tiết thay đổi thứ ba.
```

#### Các kiểu commit thường gặp:
- `feat`: Tính năng mới (Feature)
- `fix`: Sửa lỗi (Bug fix)
- `refactor`: Tái cấu trúc mã nguồn (không thêm tính năng hay sửa lỗi)
- `perf`: Tối ưu hóa hiệu năng (Performance)
- `chore`: Cập nhật cấu hình build, công cụ phát triển, hoặc thư viện ngoài
- `docs`: Cập nhật tài liệu (Readme, hướng dẫn)
- `style`: Định dạng mã nguồn (khoảng trắng, dấu chấm phẩy, không ảnh hưởng đến logic chạy)

### 3. Quy tắc viết nội dung chi tiết
- **Ngôn ngữ**: Sử dụng tiếng Việt rõ ràng, chuyên nghiệp, chuẩn thuật ngữ lập trình (ví dụ: "App Bundle", "atomic", "tái cấu trúc", "biên dịch", "luồng xử lý", "luồng giao diện").
- **Đầy đủ ý chính**: Phản ánh chính xác các tệp tin quan trọng đã sửa đổi và lý do sửa đổi.
- **Dễ đọc**: Sử dụng dấu gạch đầu dòng `-` cho các mục chi tiết.
- **Đóng khung mã nguồn**: Đặt toàn bộ nội dung commit trong một khối code block dạng `text` hoặc `markdown` để người dùng dễ dàng sao chép bằng 1 cú nhấp chuột.
