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
1. **Đồng bộ hóa cấu hình qua XcodeGen**:
   - Khi có thêm mới, di chuyển hoặc xóa tệp tin, hãy kiểm tra xem thư mục tệp tin đó có nằm trong các thư mục được XcodeGen tự động quét (như `LocalTTS/`) hay không.
   - Nếu thay đổi các cài đặt build, bundle ID, hoặc thêm thư viện SPM ngoài, phải khai báo đầy đủ trong file cấu hình [project.yml](file:///d:/Study/LocalTTS/project.yml). Tuyệt đối không lưu thủ công file `.xcodeproj` vào Git.
2. **Kiểm tra sự tương thích của API và Target Version**:
   - Xác nhận các API mới sử dụng tương thích với iOS tối thiểu được hỗ trợ (iOS Deployment Target đặt là **iOS 17.0** trong `project.yml`). Tránh sử dụng các API quá mới (ví dụ: iOS 17/18+) mà không có kiểm tra phiên bản `@available`.
3. **Kiểm tra sự phụ thuộc thư viện (Dependencies)**:
   - Nếu sử dụng thêm các thư viện ngoài, phải được khai báo đầy đủ trong cấu hình Swift Package Manager (SPM) của file [project.yml](file:///d:/Study/LocalTTS/project.yml) để CI/CD có thể tự động tải và liên kết (resolve dependencies).
4. **Kiểm tra cấu hình Workflow (.yml)**:
   - File `.github/workflows/build-ipa.yml` đã được dọn dẹp chỉ giữ lại job `unsigned-ipa`. Hãy đảm bảo các bước cài đặt XcodeGen (`brew install xcodegen`) và sinh dự án (`xcodegen generate`) được thực hiện trước khi chạy lệnh biên dịch `xcodebuild`.
