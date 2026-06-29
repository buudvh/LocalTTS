import SwiftUI

struct AddWordSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var key = ""
    @State private var value = ""
    @State private var validationError: String? = nil

    let onAdd: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin từ mới") {
                    TextField("Từ gốc (tiếng Anh/Nhật, e.g. apple)", text: $key)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: key) { oldValue, newValue in
                            validateKey(newValue)
                        }

                    TextField("Phiên âm tiếng Việt (e.g. ép pô)", text: $value)
                        .autocorrectionDisabled()
                }

                if let validationError = validationError {
                    Section {
                        Text(validationError)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Thêm từ mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        onAdd(key, value)
                        dismiss()
                    }
                    .disabled(key.trimmed.isEmpty || value.trimmed.isEmpty || validationError != nil)
                }
            }
        }
    }

    private func validateKey(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains(" ") {
            validationError = "Từ gốc không được chứa khoảng trắng"
        } else if trimmed.rangeOfCharacter(from: CharacterSet.punctuationCharacters) != nil {
            validationError = "Từ gốc không được chứa dấu câu"
        } else {
            validationError = nil
        }
    }
}
