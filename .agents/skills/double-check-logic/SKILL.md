---
name: double-check-logic
description: Hướng dẫn thực hiện quy trình kiểm tra chéo (Double-Check Logic) toàn diện sau khi sửa mã nguồn để đảm bảo độ tin cậy và không xảy ra crash.
---

# Double-Check Logic Skill

Skill này hướng dẫn quy trình kiểm tra chéo logic sau khi sửa đổi mã nguồn bằng cách chia nhỏ công việc kiểm tra cho các sub-agent, tích hợp kiểm thử và xác nhận biên dịch không có lỗi.

## Quy trình thực hiện

### Bước 1: Phân tích các phần bị ảnh hưởng (Impact Analysis)
- Liệt kê các module, hàm, hoặc cấu trúc dữ liệu bị ảnh hưởng bởi thay đổi.
- Xác định các kịch bản kiểm thử cần thiết cho từng phần.

### Bước 2: Chia nhỏ tác vụ kiểm tra (Sub-agents Verification)
- Khởi tạo các sub-agent nhỏ chuyên biệt (sử dụng công cụ `define_subagent` và `invoke_subagent`) để rà soát chi tiết từng phần logic.
  - Sub-agent 1: Kiểm tra tính an toàn của bộ nhớ, căn biên (alignment-safe), tránh tràn số hoặc tràn mảng.
  - Sub-agent 2: Kiểm tra tính logic nghiệp vụ, các trường hợp biên (edge cases), giá trị rỗng/mặc định.
  - Sub-agent 3: Kiểm tra luồng xử lý dữ liệu đầu vào và đầu ra của các hàm bị sửa đổi.

### Bước 3: Kiểm thử tích hợp tổng thể (Integration Testing)
- Sau khi các sub-agent đã xác nhận từng phần logic hoạt động bình thường, khởi tạo một sub-agent hoặc một phiên thử nghiệm để chạy tích hợp toàn bộ luồng dữ liệu (end-to-end flow).
- Chạy kịch bản mô phỏng (ví dụ: mô phỏng trên Python hoặc viết test case nhỏ) để đảm bảo các thành phần hoạt động hài hòa và không xung đột với nhau.

### Bước 4: Kiểm tra biên dịch và đóng gói (Compilation & Build Verification)
- Kiểm tra xem Xcode Project hoặc quy trình build tự động có bất kỳ lỗi biên dịch nào không.
- Xác nhận các tệp mới đã được đăng ký đầy đủ vào project để build IPA thành công.

### Bước 5: Rà soát tích hợp CI/CD (GitHub Actions Build Guard)
Để đảm bảo quy trình tự động build IPA trên GitHub Actions không bị lỗi (fail action), bắt buộc phải thực hiện các bước kiểm tra chéo sau:
1. **Kiểm tra tham chiếu Xcode Project (`.pbxproj`)**:
   - Khi có thêm mới, di chuyển hoặc xóa tệp tin, phải xác nhận các thay đổi đó đã được cập nhật đồng bộ trong tệp dự án `LocalTTS.xcodeproj/project.pbxproj`. Việc thiếu tham chiếu file trong cấu trúc project sẽ khiến build trên CI/CD bị lỗi "file not found".
2. **Kiểm tra sự tương thích của API và Target Version**:
   - Xác nhận các API mới sử dụng không vượt quá phiên bản iOS tối thiểu được hỗ trợ (iOS Deployment Target). Tránh sử dụng các API quá mới (ví dụ: iOS 17/18+) mà không có kiểm tra phiên bản `@available`.
3. **Kiểm tra sự phụ thuộc thư viện (Dependencies)**:
   - Nếu sử dụng thêm các thư viện mới (ví dụ: `import Accelerate`), phải kiểm tra xem thư viện đó có phải là framework hệ thống có sẵn của iOS không. Nếu là thư viện ngoài, phải được khai báo đầy đủ trong cấu hình Swift Package Manager (SPM) hoặc CocoaPods để CI/CD có thể tự động tải và liên kết (resolve dependencies).
4. **Kiểm tra cú pháp và cấu hình Workflow (.yml)**:
   - Đảm bảo không làm thay đổi các đường dẫn đầu ra (build path, artifact path) được khai báo trong file workflow `.github/workflows/build-ipa.yml` trừ khi có chủ ý thay đổi cấu trúc đóng gói.
