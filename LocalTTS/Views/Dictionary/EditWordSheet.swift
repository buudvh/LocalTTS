import SwiftUI

struct EditWordSheet: View {
    @Environment(\.dismiss) var dismiss
    let key: String
    @State private var value: String
    let onSave: (String) -> Void

    init(key: String, value: String, onSave: @escaping (String) -> Void) {
        self.key = key
        self._value = State(initialValue: value)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sửa phiên âm") {
                    LabeledContent("Từ gốc", value: key)
                        .foregroundStyle(.secondary)

                    TextField("Phiên âm tiếng Việt", text: $value)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Sửa từ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        onSave(value)
                        dismiss()
                    }
                    .disabled(value.trimmed.isEmpty)
                }
            }
        }
    }
}
