---
name: validate-ci-build
description: Hướng dẫn kiểm tra chéo mã nguồn để đảm bảo quá trình tự động build IPA trên GitHub Actions không bị lỗi.
---

# Validate CI/CD Build Skill

Sử dụng skill này khi bạn thực hiện các thay đổi mã nguồn trong dự án iOS LocalTTS và cần xác nhận tuyệt đối rằng các thay đổi này sẽ không làm đổ vỡ (fail) pipeline tự động build IPA trên GitHub Actions.

## Các Hạng Mục Kiểm Tra Bắt Buộc (CI Build Guard Checklist)

### 1. Kiểm tra tham chiếu tệp tin trong Xcode Project (`.pbxproj`)
Khi có bất kỳ thay đổi nào liên quan đến tệp tin:
- **Thêm tệp mới / Xóa tệp cũ / Di chuyển tệp**: Bạn **bắt buộc** phải cập nhật đồng bộ cấu trúc trong tệp `LocalTTS.xcodeproj/project.pbxproj`.
- **Hệ quả nếu thiếu**: GitHub Actions sẽ báo lỗi biên dịch `"no such file or directory"` hoặc `"file not found"` do Xcode không tìm thấy đường dẫn tệp được đăng ký trong target build.
- **Cách khắc phục**: Hãy mở dự án bằng Xcode trên máy Mac để tự động lưu cấu trúc cập nhật, hoặc chỉnh sửa thủ công `.pbxproj` một cách cẩn thận nếu đang thao tác trên Windows.

### 2. Kiểm tra độ tương thích của API & iOS Deployment Target
- **iOS Target Version**: Xác định phiên bản iOS tối thiểu mà dự án hỗ trợ (Deployment Target) trong cấu hình dự án.
- **Tránh sử dụng API quá mới**: Không sử dụng các thành phần giao diện hoặc API Swift quá mới mà không bọc trong khối kiểm tra phiên bản:
  ```swift
  if #available(iOS 17.0, *) {
      // API của iOS 17 trở lên
  } else {
      // Phương án fallback cho các iOS cũ hơn
  }
  ```
- **iPad Support**: Các thành phần hiển thị dạng popover hoặc modal hệ thống (ví dụ: `UIActivityViewController`, `ShareLink` trên iPad) phải được cấu hình `popoverPresentationController` (sourceView, sourceRect) đầy đủ để tránh ứng dụng bị crash khi kiểm thử trên thiết bị màn hình lớn.

### 3. Kiểm tra An toàn đa luồng & Concurrency
- **Main Actor Protection**: Các thay đổi tác động trực tiếp đến giao diện người dùng (Sửa đổi biến `@State`, `@Published`, hiển thị sheet, cảnh báo) từ các hàm bất đồng bộ (`async`) phải được điều hướng về luồng chính.
- **Giải pháp**: Annotate lớp hoặc cấu trúc giao diện với `@MainActor` để compiler tự động bảo vệ luồng giao diện:
  ```swift
  @MainActor
  struct MyView: View { ... }
  ```
- **Tránh data races khi tải/xóa hàng loạt**: Không chạy song song nhiều Task làm mới danh sách dữ liệu đồng thời nếu chúng tác động chung vào một biến trạng thái.

### 4. Chạy kiểm thử tự động cục bộ (Pre-flight Validation Script)
- Trước khi thực hiện lệnh push lên repository, **bắt buộc** phải chạy tất cả các kịch bản python kiểm tra trong thư mục `Scripts/` (ví dụ: `validate_text_preprocessor.py`).
- **Cách chạy trên Windows**:
  ```cmd
  python Scripts/validate_text_preprocessor.py
  ```
- Hãy đảm bảo kịch bản in ra kết quả kiểm tra thành công (`passed`) và không ném ra bất kỳ biệt lệ (`SystemExit`) nào.

### 5. Kiểm tra sự phụ thuộc thư viện (Dependencies)
- Nếu import thêm bất kỳ thư viện Swift nào, hãy kiểm tra xem thư viện đó có sẵn trong SDK hệ thống iOS (ví dụ: `AVFoundation`, `UniformTypeIdentifiers`, `Combine`) hay không.
- Nếu là thư viện ngoài, phải đăng ký đầy đủ thông qua Swift Package Manager (SPM) hoặc CocoaPods để môi trường CI/CD có thể tự động resolve và cài đặt trước khi build.
