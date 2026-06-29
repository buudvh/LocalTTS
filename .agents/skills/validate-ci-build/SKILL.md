---
name: validate-ci-build
description: Hướng dẫn kiểm tra chéo mã nguồn để đảm bảo quá trình tự động build IPA trên GitHub Actions không bị lỗi.
---

# Validate CI/CD Build Skill

Sử dụng skill này khi bạn thực hiện các thay đổi mã nguồn trong dự án iOS LocalTTS và cần xác nhận tuyệt đối rằng các thay đổi này sẽ không làm đổ vỡ (fail) pipeline tự động build IPA trên GitHub Actions.

## Các Hạng Mục Kiểm Tra Bắt Buộc (CI Build Guard Checklist)

### 1. Cấu hình Dự án Xcode qua XcodeGen (`project.yml`)
Dự án đã được chuyển đổi sang sử dụng **XcodeGen** để tự động sinh file dự án. Khi có bất kỳ thay đổi cấu trúc nào:
- **Thêm/Xóa/Di chuyển tệp tin**: Bạn chỉ cần thao tác trực tiếp trên ổ đĩa trong thư mục `LocalTTS`. Thư mục `LocalTTS.xcodeproj` đã được đưa vào `.gitignore` và không còn được theo dõi bởi Git.
- **Thay đổi cài đặt build, bundle ID, thư viện (SPM)**: Bạn **bắt buộc** phải chỉnh sửa file [project.yml](file:///d:/Study/LocalTTS/project.yml) thay vì sửa trên giao diện Xcode.
- **Đồng bộ hóa cục bộ (máy Mac)**: Bạn cần chạy lệnh `xcodegen generate` trong thư mục dự án trước khi mở Xcode hoặc chạy build.
- **Hệ quả nếu thiếu**: GitHub Actions sẽ cài đặt XcodeGen và tự động sinh dự án từ `project.yml` trước khi build. Nếu bạn không khai báo các file mới hoặc cấu hình mới trong `project.yml` (hoặc cấu trúc thư mục sai), CI sẽ bị lỗi biên dịch.

### 2. Kiểm tra độ tương thích của API & iOS Deployment Target
- **iOS Target Version**: Xác định phiên bản iOS tối thiểu mà dự án hỗ trợ (Deployment Target là **iOS 17.0** trong `project.yml`).
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
- Nếu là thư viện ngoài, phải đăng ký đầy đủ thông qua phần `packages` và `dependencies` trong file [project.yml](file:///d:/Study/LocalTTS/project.yml) để XcodeGen có thể sinh ra liên kết thư viện chính xác và môi trường CI/CD có thể tự động resolve trước khi build.
