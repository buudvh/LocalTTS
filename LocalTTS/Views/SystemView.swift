import SwiftUI

struct SystemView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var activeTab: TabType
    
    @State private var isShowingSettings = false
    @State private var toast: ToastConfig? = nil
    @State private var toastTask: Task<Void, Never>? = nil

    struct ToastConfig: Identifiable {
        let id = UUID()
        let message: String
        let isError: Bool
    }

    private func showToast(_ message: String, isError: Bool) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            toast = ToastConfig(message: message, isError: isError)
        }
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                toast = nil
            }
        }
    }

    private func dismissToast() {
        toastTask?.cancel()
        toastTask = nil
        withAnimation(.easeOut(duration: 0.25)) {
            toast = nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                let hasNoModels = appState.modelStore.getLocalVoiceIDs().isEmpty
                let hasNoDictionary = !FileManager.default.fileExists(atPath: appState.modelStore.rootURL.appendingPathComponent("non-vietnamese-words.plist").path)

                if hasNoModels || hasNoDictionary {
                    Section("Cảnh báo hệ thống") {
                        if hasNoModels {
                            HStack {
                                Label("Chưa tải model nào", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Spacer()
                                Button("Thực hiện") {
                                    activeTab = .model
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        if hasNoDictionary {
                            HStack {
                                Label("Chưa tải từ điển", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Spacer()
                                Button("Thực hiện") {
                                    activeTab = .dictionary
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                Section("Cấu hình") {
                    Button(action: {
                        isShowingSettings = true
                    }) {
                        Label("Cài đặt", systemImage: "gearshape")
                    }
                    .sheet(isPresented: $isShowingSettings) {
                        SettingsView()
                    }
                }

                Section("Server") {
                    HStack {
                        Text(appState.server.isRunning ? "Đang bật" : "Dừng")
                        Spacer()
                        Circle()
                            .fill(appState.server.isRunning ? Color.green : Color.gray)
                            .frame(width: 10, height: 10)
                    }

                    Text("http://127.0.0.1:17771")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)

                    if let lastRequest = appState.server.lastRequest {
                        Text(lastRequest)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button(appState.server.isRunning ? "Tắt Server" : "Bật Server") {
                        if appState.server.isRunning {
                            appState.stopServer()
                        } else {
                            appState.startServer()
                        }
                    }
                }
                
                Section("Engine") {
                    Text(appState.ttsService.engineStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Logs") {
                    Button("Xuất logs") {
                        shareLogFile()
                    }
                    
                    Button("Dọn dẹp logs", role: .destructive) {
                        AppLogger.shared.clearLogs()
                        showToast("Đã xóa toàn bộ nhật ký log thành công.", isError: false)
                    }
                }

                if let error = appState.lastError {
                    Section("Error") {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Hệ thống")
            .safeAreaInset(edge: .bottom) {
                if let toast = toast {
                    HStack(spacing: 10) {
                        Image(systemName: toast.isError
                            ? "exclamationmark.circle.fill"
                            : "checkmark.circle.fill")

                        Text(toast.message)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .onTapGesture {
                        dismissToast()
                    }
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                    .zIndex(1000)
                }
            }
        }
    }

    private func shareLogFile() {
        let logFolderURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let logURL = logFolderURL.appendingPathComponent("app.log")
        
        guard FileManager.default.fileExists(atPath: logURL.path) else {
            showToast("Không tìm thấy tệp nhật ký log.", isError: true)
            return
        }
        
        #if canImport(UIKit)
        let activityVC = UIActivityViewController(activityItems: [logURL], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true, completion: nil)
        }
        #endif
    }
}
