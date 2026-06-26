import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

enum TabType: Hashable {
    case tts
    case model
    case dictionary
    case system
}

@MainActor
struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var voices: [Voice] = []
    @State private var isLoadingVoices = false
    @State private var selectedVoice = NghiTTSClient.defaultVietnameseVoice
    @State private var prefetchStatus = ""
    @State private var isShowingSettings = false
    @State private var testText = "Xin chào, đây là thử giọng tiếng Việt."
    @State private var testSpeed = 1.0
    @State private var isSynthesizing = false
    @State private var testAudioPlayer: AVAudioPlayer? = nil
    @State private var isDownloadingAll = false
    @State private var downloadProgress = ""
    @State private var isShowingFileImporter = false
    
    // Progress variables for model downloading
    @State private var isDownloadingModel = false
    @State private var downloadProgressValue: Double = 0.0
    @State private var downloadMessage = ""
    @State private var isImportingModel = false
    @State private var importModelMessage = "Đang nhập model..."
    
    // Tab navigation and refresh trigger
    @State private var activeTab: TabType = .tts
    @State private var modelRefreshTrigger = 0
    @State private var systemTabRefreshTrigger = 0
    
    // Progress variables for model downloading in Model tab
    @State private var downloadingStatus: [String: Double] = [:]
    @State private var downloadingMessages: [String: String] = [:]
    
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

    // Voice categorization helpers
    private var topVoices: [Voice] {
        let topNames = ["Ngọc Huyền (mới)", "Mai Phương", "Duy Onyx (mới)", "Ngọc Ngạn"].map { $0.precomposedStringWithCanonicalMapping }
        return NghiTTSClient.fallbackVietnameseVoices.filter { topNames.contains($0.name.precomposedStringWithCanonicalMapping) }
    }

    private var systemVoices: [Voice] {
        let _ = modelRefreshTrigger
        let topNames = ["Ngọc Huyền (mới)", "Mai Phương", "Duy Onyx (mới)", "Ngọc Ngạn"].map { $0.precomposedStringWithCanonicalMapping }
        let baseVoices = NghiTTSClient.fallbackVietnameseVoices.filter { !topNames.contains($0.name.precomposedStringWithCanonicalMapping) }
        
        let downloaded = baseVoices.filter { appState.modelStore.modelExists(for: $0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let notDownloaded = baseVoices.filter { !appState.modelStore.modelExists(for: $0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            
        return downloaded + notDownloaded
    }

    private var customVoices: [Voice] {
        let _ = modelRefreshTrigger
        let localIDs = appState.modelStore.getLocalVoiceIDs()
        let fallbackIDs = NghiTTSClient.fallbackVietnameseVoices.map { $0.id }
        let customIDs = localIDs.filter { !fallbackIDs.contains($0) }
        let unsorted = customIDs.map { id in
            let name = id.replacingOccurrences(of: "_", with: " ").capitalized
            return Voice(id: id, name: name)
        }
        return unsorted.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }


    var body: some View {
        ZStack {
            TabView(selection: $activeTab) {
                // Tab 1: TTS
                NavigationStack {
                    Form {
                        Section("Giọng đọc") {
                            if isLoadingVoices {
                                ProgressView()
                            }

                            Picker("Giọng đọc", selection: $selectedVoice) {
                                ForEach(voices.isEmpty ? [selectedVoice] : voices, id: \.self) { voice in
                                    Text(voice.name).tag(voice)
                                }
                            }

                            Button("Làm mới danh sách giọng đọc") {
                                Task { await loadVoices(forceRefresh: true) }
                            }

                            Button("Tải trước model đã chọn") {
                                Task { await prefetchSelectedVoice() }
                            }
                            .disabled(isDownloadingModel || isLoadingVoices)

                            if isDownloadingModel {
                                ProgressView(value: downloadProgressValue) {
                                    Text(downloadMessage)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            }

                            if !prefetchStatus.isEmpty {
                                Text(prefetchStatus)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section("Test giọng đọc") {
                            HStack {
                                TextField("Văn bản cần đọc", text: $testText, axis: .vertical)
                                    .lineLimit(3...10)
                                
                                if !testText.isEmpty {
                                    Button(action: {
                                        testText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            Slider(value: $testSpeed, in: 0.5...2.0, step: 0.1) {
                                Text("Speed")
                            } minimumValueLabel: {
                                Text("0.5x")
                            } maximumValueLabel: {
                                Text("2.0x")
                            }
                            
                            Text(String(format: "Speed: %.1fx", testSpeed))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button(isSynthesizing ? "Đang xử lý..." : "Đọc") {
                                Task { await testTTS() }
                            }
                            .disabled(isSynthesizing || testText.trimmed.isEmpty)
                        }

                        if let error = appState.lastError {
                            Section("Error") {
                                Text(error)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .navigationTitle("LocalTTS")
                }
                .tabItem {
                    Label("TTS", systemImage: "waveform.and.mic")
                }
                .tag(TabType.tts)
                
                // Tab 2: Model (Quản lý Model)
                NavigationStack {
                    List {
                        Section {
                            Button(action: {
                                isShowingFileImporter = true
                            }) {
                                Label("Nhập Model Ngoài...", systemImage: "square.and.arrow.down")
                            }
                        }
                        
                        Section(header: HStack {
                            Text("Giọng đọc đặc sắc")
                            Spacer()
                            HStack(spacing: 12) {
                                Button("Tải tất cả") {
                                    downloadAll(in: topVoices)
                                }
                                .buttonStyle(.borderless)
                                .textCase(.none)
                                .font(.caption)
                                
                                Button("Xóa tất cả", role: .destructive) {
                                    deleteAll(in: topVoices)
                                }
                                .buttonStyle(.borderless)
                                .textCase(.none)
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }) {
                            ForEach(topVoices) { voice in
                                modelRow(for: voice)
                            }
                        }
                        
                        Section(header: HStack {
                            Text("Giọng đọc hệ thống")
                            Spacer()
                            HStack(spacing: 12) {
                                Button("Tải tất cả") {
                                    downloadAll(in: systemVoices)
                                }
                                .buttonStyle(.borderless)
                                .textCase(.none)
                                .font(.caption)
                                
                                Button("Xóa tất cả", role: .destructive) {
                                    deleteAll(in: systemVoices)
                                }
                                .buttonStyle(.borderless)
                                .textCase(.none)
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }) {
                            ForEach(systemVoices) { voice in
                                modelRow(for: voice)
                            }
                        }
                        
                        let custom = customVoices
                        if !custom.isEmpty {
                            Section(header: HStack {
                                Text("Giọng đọc tùy chỉnh")
                                Spacer()
                                Button("Xóa tất cả", role: .destructive) {
                                    deleteAll(in: custom)
                                }
                                .buttonStyle(.borderless)
                                .textCase(.none)
                                .font(.caption)
                                .foregroundColor(.red)
                            }) {
                                ForEach(custom) { voice in
                                    modelRow(for: voice, isCustom: true)
                                }
                            }
                        }
                    }
                    .navigationTitle("Quản lý Model")
                    .background {
                        DocumentPickerPresenter(
                            isPresented: $isShowingFileImporter,
                            allowedContentTypes: [.onnx, .json],
                            allowsMultipleSelection: true,
                            onPick: { urls in
                                handleModelImportPick(urls: urls)
                            },
                            onCancel: nil
                        )
                    }
                }
                .tabItem {
                    Label("Model", systemImage: "arrow.down.circle")
                }
                .tag(TabType.model)

                // Tab 3: Từ điển (Màn hình Xóa/Sửa từ trực tiếp)
                NavigationStack {
                    DictionaryEditView()
                }
                .tabItem {
                    Label("Từ điển", systemImage: "character.book.closed")
                }
                .tag(TabType.dictionary)
                
                // Tab 4: Hệ thống
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
                }
                .tabItem {
                    Label("Hệ thống", systemImage: "server.rack")
                }
                .tag(TabType.system)
                .id(systemTabRefreshTrigger)
            }
            .onChange(of: activeTab) { newTab in
                if newTab == .system {
                    systemTabRefreshTrigger += 1
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .task {
                appState.startServer()
                await loadVoices(forceRefresh: false)
            }
            .dismissKeyboardOnTap()
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
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                    .onTapGesture {
                        dismissToast()
                    }
                }
            }

            if isImportingModel {
                Color.black.opacity(0.35)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                    .zIndex(998)

                VStack(spacing: 16) {
                    ProgressView(importModelMessage)
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(radius: 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(999)
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: toast != nil)
        .zIndex(999)
    }

    @ViewBuilder
    private func modelRow(for voice: Voice, isCustom: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(voice.name)
                    .font(.body)
                
                let isDownloaded = appState.modelStore.modelExists(for: voice.id)
                if isDownloaded {
                    let bytes = appState.modelStore.bytesForVoice(voice.id)
                    Text(String(format: "Dung lượng: %.1f MB", Double(bytes) / 1024.0 / 1024.0))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Trạng thái: Chưa tải")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let progress = downloadingStatus[voice.name] {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: progress)
                        Text(downloadingMessages[voice.name] ?? "Đang tải...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
            
            let isDownloading = downloadingStatus[voice.name] != nil
            if isDownloading {
                ProgressView()
            } else {
                let isDownloaded = appState.modelStore.modelExists(for: voice.id)
                HStack(spacing: 8) {
                    if isDownloaded {
                        if !isCustom {
                            Button("Tải lại") {
                                Task {
                                    await downloadSingleModel(voice: voice)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Button("Xóa", role: .destructive) {
                            deleteSingleModel(voice: voice)
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    } else {
                        Button("Tải") {
                            Task {
                                await downloadSingleModel(voice: voice)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func downloadSingleModel(voice: Voice) async {
        downloadingStatus[voice.name] = 0.0
        downloadingMessages[voice.name] = "Bắt đầu tải..."
        
        do {
            _ = try await appState.nghiClient.prefetchModels(voices: [voice.name]) { msg, progress in
                DispatchQueue.main.async {
                    self.downloadingStatus[voice.name] = progress
                    self.downloadingMessages[voice.name] = msg
                }
            }
            DispatchQueue.main.async {
                self.downloadingStatus.removeValue(forKey: voice.name)
                self.downloadingMessages.removeValue(forKey: voice.name)
                self.modelRefreshTrigger += 1
            }
            await loadVoices(forceRefresh: false)
        } catch {
            DispatchQueue.main.async {
                self.downloadingStatus.removeValue(forKey: voice.name)
                self.downloadingMessages.removeValue(forKey: voice.name)
                self.appState.lastError = "Lỗi tải model \(voice.name): \(error.localizedDescription)"
            }
        }
    }

    private func deleteSingleModel(voice: Voice) {
        do {
            try appState.modelStore.deleteModel(for: voice.id)
            modelRefreshTrigger += 1
            showToast("Đã xóa model \(voice.name) thành công.", isError: false)
            Task {
                await loadVoices(forceRefresh: false)
            }
        } catch {
            showToast("Lỗi xóa model \(voice.name): \(error.localizedDescription)", isError: true)
            appState.lastError = "Lỗi xóa model \(voice.name): \(error.localizedDescription)"
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

    private func downloadAll(in list: [Voice]) {
        let toDownload = list.filter { !appState.modelStore.modelExists(for: $0.id) && downloadingStatus[$0.name] == nil }
        for voice in toDownload {
            Task {
                await downloadSingleModel(voice: voice)
            }
        }
    }

    private func deleteAll(in list: [Voice]) {
        let toDelete = list.filter { appState.modelStore.modelExists(for: $0.id) }
        guard !toDelete.isEmpty else { return }
        for voice in toDelete {
            do {
                try appState.modelStore.deleteModel(for: voice.id)
            } catch {
                appState.lastError = "Lỗi xóa model \(voice.name): \(error.localizedDescription)"
            }
        }
        modelRefreshTrigger += 1
        Task {
            await loadVoices(forceRefresh: false)
        }
    }

    private func loadVoices(forceRefresh: Bool) async {
        isLoadingVoices = true
        defer { isLoadingVoices = false }

        do {
            let allVoices = try await appState.nghiClient.getAllVoices(forceRefresh: forceRefresh)
            voices = allVoices
            if !voices.contains(selectedVoice), let first = voices.first {
                selectedVoice = first
            }
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private typealias ModelImportPair = (
        onnxURL: URL,
        onnxAccess: Bool,
        jsonURL: URL,
        jsonAccess: Bool,
        voiceId: String
    )

    private func handleModelImportPick(urls: [URL]) {
        let validURLs = urls.filter {
            let ext = $0.pathExtension.lowercased()
            return ext == "onnx" || ext == "json"
        }
        if validURLs.isEmpty {
            reportImportError("Vui lòng chọn tệp tin model (.onnx) và cấu hình (.json).")
            return
        }

        let onnxURLs = validURLs.filter { $0.pathExtension.lowercased() == "onnx" }
        let jsonURLs = validURLs.filter { $0.pathExtension.lowercased() == "json" }

        if onnxURLs.isEmpty || jsonURLs.isEmpty {
            reportImportError("Cần chọn cả hai tệp .onnx và .json cho model. Vui lòng thử lại.")
            return
        }

        func voiceId(for url: URL) -> String {
            let baseName = url.deletingPathExtension().lastPathComponent
            if url.pathExtension.lowercased() == "json", baseName.lowercased().hasSuffix(".onnx") {
                return String(baseName.dropLast(5)).toASCIIID
            }
            return baseName.toASCIIID
        }

        let jsonById = Dictionary(uniqueKeysWithValues: jsonURLs.compactMap { url in
            let id = voiceId(for: url)
            return id.isEmpty ? nil : (id, url)
        })

        var pairedFiles: [(onnxURL: URL, jsonURL: URL, voiceId: String)] = []
        var missingJSON: [String] = []
        for onnxURL in onnxURLs {
            let id = voiceId(for: onnxURL)
            if let jsonURL = jsonById[id] {
                pairedFiles.append((onnxURL: onnxURL, jsonURL: jsonURL, voiceId: id))
            } else {
                missingJSON.append(onnxURL.lastPathComponent)
            }
        }

        if !missingJSON.isEmpty {
            reportImportError("Thiếu tệp .json tương ứng cho: \(missingJSON.joined(separator: ", ")).")
            return
        }

        let pairsWithAccess = pairedFiles.map { pair in
            (
                onnxURL: pair.onnxURL,
                onnxAccess: pair.onnxURL.startAccessingSecurityScopedResource(),
                jsonURL: pair.jsonURL,
                jsonAccess: pair.jsonURL.startAccessingSecurityScopedResource(),
                voiceId: pair.voiceId
            )
        }

        isImportingModel = true
        importModelMessage = "Đang nhập model..."
        showToast("Đang nhập model...", isError: false)

        let result = performModelImportSync(from: pairsWithAccess)
        isImportingModel = false

        modelRefreshTrigger += 1
        Task {
            await finishModelImport(result: result, modelCount: pairsWithAccess.count)
        }
    }

    private func reportImportError(_ message: String) {
        appState.lastError = message
        showToast(message, isError: true)
    }

    private struct ModelImportResult {
        let importCount: Int
        let errorCount: Int
        let lastErrorMessage: String?
    }

    private func performModelImportSync(from pairs: [ModelImportPair]) -> ModelImportResult {
        let fm = FileManager.default
        var importCount = 0
        var errorCount = 0
        var lastErrorMessage: String?

        for pair in pairs {
            let onnxURL = pair.onnxURL
            let jsonURL = pair.jsonURL
            let voiceId = pair.voiceId

            defer {
                if pair.onnxAccess {
                    onnxURL.stopAccessingSecurityScopedResource()
                }
                if pair.jsonAccess {
                    jsonURL.stopAccessingSecurityScopedResource()
                }
            }

            let targets: [(source: URL, destination: URL)] = [
                (source: onnxURL, destination: appState.modelStore.modelURL(for: voiceId, extension: "onnx")),
                (source: jsonURL, destination: appState.modelStore.modelURL(for: voiceId, extension: "onnx.json"))
            ]

            for item in targets {
                var cleanupURL: URL?
                do {
                    let resourceValues = try item.source.resourceValues(forKeys: [.fileSizeKey])
                    let fileSize = resourceValues.fileSize ?? 0
                    if fileSize <= 0 {
                        throw NSError(domain: "ContentView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Tệp \(item.source.lastPathComponent) trống hoặc không thể đọc."])
                    }

                    if item.source.pathExtension.lowercased() == "json" {
                        let data = try Data(contentsOf: item.source)
                        guard let _ = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                            throw NSError(domain: "ContentView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cấu hình JSON \(item.source.lastPathComponent) không hợp lệ."])
                        }
                    }

                    if fm.fileExists(atPath: item.destination.path) {
                        try fm.removeItem(at: item.destination)
                    }

                    cleanupURL = item.destination
                    try streamCopy(from: item.source, to: item.destination)
                    importCount += 1
                } catch {
                    let message = error.localizedDescription
                    appLog("Failed to import file \(item.source.lastPathComponent): \(message)")
                    lastErrorMessage = message
                    if let cleanupURL = cleanupURL, fm.fileExists(atPath: cleanupURL.path) {
                        try? fm.removeItem(at: cleanupURL)
                    }
                    errorCount += 1
                }
            }
        }

        appLog("Imported \(importCount) files. Errors: \(errorCount)")
        return ModelImportResult(
            importCount: importCount,
            errorCount: errorCount,
            lastErrorMessage: lastErrorMessage
        )
    }

    private func finishModelImport(result: ModelImportResult, modelCount: Int) async {
        await loadVoices(forceRefresh: false)

        if result.errorCount > 0 {
            let message = "Lỗi nhập model/cấu hình. Vui lòng kiểm tra lại các cặp .onnx và .json."
            appState.lastError = result.lastErrorMessage ?? message
            showToast(message, isError: true)
        } else if result.importCount > 0 {
            appState.lastError = nil
            showToast("Đã nhập thành công \(modelCount) model.", isError: false)
        } else {
            let message = "Không thể nhập model. Vui lòng kiểm tra lại tệp đã chọn."
            appState.lastError = message
            showToast(message, isError: true)
        }
    }

    private func streamCopy(from sourceURL: URL, to destinationURL: URL) throws {
        guard let inputStream = InputStream(url: sourceURL) else {
            throw NSError(domain: "StreamCopy", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open input stream for \(sourceURL.lastPathComponent)"])
        }
        guard let outputStream = OutputStream(url: destinationURL, append: false) else {
            throw NSError(domain: "StreamCopy", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to open output stream for \(destinationURL.lastPathComponent)"])
        }
        
        inputStream.open()
        defer { inputStream.close() }
        outputStream.open()
        defer { outputStream.close() }
        
        let bufferSize = 65536 // 64KB
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(buffer, maxLength: bufferSize)
            if bytesRead < 0 {
                if let error = inputStream.streamError {
                    throw error
                }
                throw NSError(domain: "StreamCopy", code: 3, userInfo: [NSLocalizedDescriptionKey: "Error reading input stream"])
            } else if bytesRead == 0 {
                break // End of file
            }
            
            var bytesWritten = 0
            while bytesWritten < bytesRead {
                let written = outputStream.write(buffer.advanced(by: bytesWritten), maxLength: bytesRead - bytesWritten)
                if written < 0 {
                    if let error = outputStream.streamError {
                        throw error
                    }
                    throw NSError(domain: "StreamCopy", code: 4, userInfo: [NSLocalizedDescriptionKey: "Error writing output stream"])
                }
                bytesWritten += written
            }
        }
    }

    private func prefetchSelectedVoice() async {
        isDownloadingModel = true
        downloadProgressValue = 0.0
        downloadMessage = "Bắt đầu tải..."
        prefetchStatus = ""
        defer { isDownloadingModel = false }
        
        do {
            let result = try await appState.nghiClient.prefetchModels(voices: [selectedVoice.name]) { msg, progress in
                DispatchQueue.main.async {
                    self.downloadMessage = msg
                    self.downloadProgressValue = progress
                }
            }
            prefetchStatus = result.first?.message ?? "Tải hoàn tất!"
            modelRefreshTrigger += 1
        } catch {
            prefetchStatus = "Lỗi: \(error.localizedDescription)"
        }
    }

    private func testTTS() async {
        isSynthesizing = true
        appState.lastError = nil
        defer { isSynthesizing = false }
        
        do {
            appLog("Starting UI TTS test for voice: \(selectedVoice.name), speed: \(testSpeed)")
            let audioData = try await appState.ttsService.synthesize(
                text: testText,
                voice: selectedVoice.name,
                speed: testSpeed
            )
            
            appLog("Synthesis complete, audio data size: \(audioData.count) bytes. Playing...")
            testAudioPlayer = try AVAudioPlayer(data: audioData)
            testAudioPlayer?.prepareToPlay()
            testAudioPlayer?.play()
        } catch {
            appLog("UI TTS test failed: \(error.localizedDescription)")
            appState.lastError = error.localizedDescription
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    @AppStorage(PreprocessorSettingKey.numericNormalizationEnabled) private var preprocessorNumericNormalizationEnabled = true
    @AppStorage(PreprocessorSettingKey.dictionaryReplacementEnabled) private var preprocessorDictionaryReplacementEnabled = true
    @AppStorage(PreprocessorSettingKey.transliterationEnabled) private var preprocessorTransliterationEnabled = true
    @AppStorage(PreprocessorSettingKey.debugLoggingEnabled) private var preprocessorDebugLoggingEnabled = false
    
    @AppStorage("newlinePauseDuration") private var newlinePause = 0.5
    @AppStorage("sentencePauseDuration") private var sentencePause = 0.4
    @AppStorage("phrasePauseDuration") private var phrasePause = 0.15
    @AppStorage("bracketPauseDuration") private var bracketPause = 0.15

    var body: some View {
        NavigationStack {
            Form {
                Section("Tiền xử lý text") {
                    Toggle("Chuẩn hóa cách đọc số", isOn: $preprocessorNumericNormalizationEnabled)
                    Toggle("Áp dụng thay thế từ điển", isOn: $preprocessorDictionaryReplacementEnabled)
                    Toggle("Phiên âm tiếng Anh/Nhật", isOn: $preprocessorTransliterationEnabled)
                    Toggle("Ghi nhật ký gỡ lỗi", isOn: $preprocessorDebugLoggingEnabled)
                }
                
                Section("Cấu hình khoảng ngắt (giây)") {
                    PrecisionSliderView(title: "Xuống dòng:", value: $newlinePause, defaultValue: 0.5)
                    PrecisionSliderView(title: "Cuối câu (. ! ?):", value: $sentencePause, defaultValue: 0.4)
                    PrecisionSliderView(title: "Giữa câu (, ; :):", value: $phrasePause, defaultValue: 0.15)
                    PrecisionSliderView(title: "Dấu ngoặc (( ) [ ] { } 「 」 etc.):", value: $bracketPause, defaultValue: 0.15)
                    
                    Button("Đặt lại mặc định") {
                        newlinePause = 0.5
                        sentencePause = 0.4
                        phrasePause = 0.15
                        bracketPause = 0.15
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Xong") {
                        dismiss()
                    }
                }
            }
        }
    }
}


struct PrecisionSliderView: View {
    let title: String
    @Binding var value: Double
    let defaultValue: Double
    var range: ClosedRange<Double> = 0.0...2.0
    var step: Double = 0.01
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.body)
                Spacer()
                
                // Minus button
                Button(action: {
                    let target = value - step
                    let rounded = (target * 100).rounded() / 100
                    value = max(range.lowerBound, min(range.upperBound, rounded))
                }) {
                    Image(systemName: "minus.circle")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
                .frame(width: 32, height: 32)
                
                // Value text
                Text(String(format: "%.2f s", value))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 50, alignment: .center)
                
                // Plus button
                Button(action: {
                    let target = value + step
                    let rounded = (target * 100).rounded() / 100
                    value = max(range.lowerBound, min(range.upperBound, rounded))
                }) {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
                .frame(width: 32, height: 32)
                
                // Reset button
                Button(action: {
                    value = defaultValue
                }) {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
                .frame(width: 32, height: 32)
            }
            
            // Slider row with min/max labels
            HStack(spacing: 8) {
                Text(String(format: "%.1f", range.lowerBound))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Slider(value: $value, in: range, step: step)
                
                Text(String(format: "%.1f", range.upperBound))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Dictionary Edit Views
@MainActor
struct DictionaryEditView: View {
    @EnvironmentObject private var appState: AppState
    @State private var allWords: [String: String] = [:]
    @State private var sortedKeys: [String] = []
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var editingKey: String? = nil
    @State private var editingValue: String = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    @State private var exportURL: URL? = nil
    @State private var exportJsonURL: URL? = nil
    @State private var exportCsvURL: URL? = nil
    
    @State private var showingFileImporter = false
    @State private var showingDownloadConfirmation = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    
    @State private var toast: ToastConfig? = nil
    @State private var toastTask: Task<Void, Never>? = nil

    struct ToastConfig: Identifiable {
        let id = UUID()
        let message: String
        let isError: Bool
    }

    private func showToast(_ message: String, isError: Bool) {
        toastTask?.cancel()

        if toast != nil {
            toast = nil
        }

        withAnimation(
            .spring(
                response: 0.4,
                dampingFraction: 0.85
            )
        ) {
            toast = ToastConfig(
                message: message,
                isError: isError
            )
        }

        toastTask = Task {
            try? await Task.sleep(for: .seconds(3))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    toast = nil
                }
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

    @State private var visibleCount = 100

    var matchedKeys: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return sortedKeys
        } else {
            return sortedKeys.filter { $0.contains(query) }
        }
    }

    var filteredKeys: [String] {
        return Array(matchedKeys.prefix(visibleCount))
    }

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Đang tải từ điển...")
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    if searchText.isEmpty {
                        Section {
                            if filteredKeys.count < sortedKeys.count {
                                Text("Hiển thị \(filteredKeys.count)/\(sortedKeys.count) từ. Cuộn xuống để tải thêm.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Đã hiển thị toàn bộ \(sortedKeys.count) từ.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Section {
                            if filteredKeys.count < matchedKeys.count {
                                Text("Hiển thị \(filteredKeys.count)/\(matchedKeys.count) từ kết quả. Cuộn xuống để tải thêm.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Đã hiển thị toàn bộ \(matchedKeys.count) từ kết quả.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Section {
                        ForEach(filteredKeys, id: \.self) { key in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(key)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(allWords[key] ?? "")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "pencil")
                                    .foregroundColor(.accentColor)
                                    .font(.subheadline)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingKey = key
                                editingValue = allWords[key] ?? ""
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteWord(key: key)
                                } label: {
                                    Label("Xóa", systemImage: "trash")
                                }
                            }
                            .onAppear {
                                if key == filteredKeys.last && visibleCount < matchedKeys.count {
                                    visibleCount += 100
                                }
                            }
                        }
                    } header: {
                        Text("Từ vựng (\(allWords.count) từ)")
                    }
                }
                .searchable(text: $searchText, prompt: "Tìm từ...")
                .onChange(of: searchText) { _ in
                    visibleCount = 100
                }
                .overlay {
                    if filteredKeys.isEmpty && !searchText.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("Không tìm thấy kết quả cho \"\(searchText)\"")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Sửa từ điển")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Menu {
                        if let plistURL = exportURL {
                            ShareLink("Property List (.plist)", item: plistURL)
                        }
                        if let jsonURL = exportJsonURL {
                            ShareLink("JSON (.json)", item: jsonURL)
                        }
                        if let csvURL = exportCsvURL {
                            ShareLink("CSV (.csv)", item: csvURL)
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button {
                        showingFileImporter = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .sheet(isPresented: $showingFileImporter) {
                        DocumentPicker(
                            allowedContentTypes: [.propertyList, .json, .commaSeparatedText, .plainText],
                            allowsMultipleSelection: false,
                            onPick: { urls in
                                guard let selectedURL = urls.first else { return }
                                let ext = selectedURL.pathExtension.lowercased()
                                if ext != "plist" && ext != "json" && ext != "csv" && ext != "txt" {
                                    showToast("Vui lòng chọn tệp từ điển (.plist, .json, hoặc .csv/.txt).", isError: true)
                                    return
                                }
                                let hasAccess = selectedURL.startAccessingSecurityScopedResource()
                                importDictionary(from: selectedURL, hasAccess: hasAccess)
                            },
                            onCancel: {
                                showingFileImporter = false
                            }
                        )
                    }

                    Button {
                        showingDownloadConfirmation = true
                    } label: {
                        Image(systemName: "arrow.down.to.line")
                    }
                    .alert("Xác nhận tải lại", isPresented: $showingDownloadConfirmation) {
                        Button("Hủy", role: .cancel) {}
                        Button("Tải lại", role: .destructive) {
                            downloadDictionaries()
                        }
                    } message: {
                        Text("Hành động này sẽ tải lại từ điển gốc từ HuggingFace và ghi đè tất cả các từ vựng tùy chỉnh bạn đã thêm. Bạn có chắc chắn muốn tiếp tục?")
                    }

                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .sheet(isPresented: $showingAddSheet) {
                        AddWordSheet(onAdd: { key, val in
                            addWord(key: key, value: val)
                        })
                    }
                }
            }
        }
        .sheet(item: Binding(
            get: { editingKey.map { EditingEntry(key: $0, value: editingValue) } },
            set: { editingKey = $0?.key; editingValue = $0?.value ?? "" }
        )) { entry in
            EditWordSheet(key: entry.key, value: entry.value) { newVal in
                updateWord(key: entry.key, value: newVal)
            }
        }
        .task {
            await loadDictionary()
        }
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
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .bottom)
                            .combined(with: .opacity),
                        removal: .opacity
                    )
                )
                .onTapGesture {
                    dismissToast()
                }
            }
        }
    }

    private func loadDictionary() async {
        isLoading = true
        let map = await TextPreprocessor.shared.getWordMap()
        allWords = map
        sortedKeys = map.keys.sorted()
        
        let fm = FileManager.default
        if let cachesURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let plistURL = cachesURL.appendingPathComponent("non-vietnamese-words.plist")
            let jsonURL = cachesURL.appendingPathComponent("dictionary.json")
            let csvURL = cachesURL.appendingPathComponent("dictionary.csv")
            
            if let plistData = try? PropertyListSerialization.data(fromPropertyList: map, format: .xml, options: 0) {
                try? plistData.write(to: plistURL, options: .atomic)
                exportURL = plistURL
            }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: map, options: [.prettyPrinted, .sortedKeys]) {
                try? jsonData.write(to: jsonURL, options: .atomic)
                exportJsonURL = jsonURL
            }
            
            let csvString = generateCSV(from: map)
            if let csvData = csvString.data(using: .utf8) {
                try? csvData.write(to: csvURL, options: .atomic)
                exportCsvURL = csvURL
            }
        }
        
        isLoading = false
    }

    private func downloadDictionaries() {
        isLoading = true
        Task {
            do {
                try await appState.nghiClient.downloadDictionaries()
                await loadDictionary()
                appState.notifyDictionaryChanged()
                showToast("Tải từ điển từ HuggingFace thành công!", isError: false)
            } catch {
                showToast("Không thể tải từ điển: \(error.localizedDescription)", isError: true)
            }
            isLoading = false
        }
    }

    private func parseCSV(data: Data) throws -> [String: String] {
        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "CSVParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Không thể đọc tệp CSV dưới dạng UTF-8."])
        }
        
        var dict: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            var fields: [String] = []
            var currentField = ""
            var insideQuotes = false
            
            let chars = Array(trimmed)
            var idx = 0
            while idx < chars.count {
                let char = chars[idx]
                
                if char == "\"" {
                    if insideQuotes && idx + 1 < chars.count && chars[idx + 1] == "\"" {
                        currentField.append("\"")
                        idx += 2
                        continue
                    } else {
                        insideQuotes.toggle()
                    }
                } else if char == "," && !insideQuotes {
                    fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
                    currentField = ""
                } else {
                    currentField.append(char)
                }
                idx += 1
            }
            fields.append(currentField.trimmingCharacters(in: .whitespacesAndNewlines))
            
            if fields.count >= 2 {
                let key = fields[0]
                let val = fields[1]
                
                if (key == "Từ gốc" || key.lowercased() == "key" || key.lowercased() == "original") &&
                   (val == "Thay thế" || val.lowercased() == "value" || val.lowercased() == "replacement") {
                    continue
                }
                
                if !key.isEmpty {
                    dict[key.lowercased()] = val
                }
            }
        }
        
        if dict.isEmpty {
            throw NSError(domain: "CSVParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Tệp CSV không chứa dữ liệu từ điển hợp lệ hoặc sai cấu trúc."])
        }
        return dict
    }
    
    private func generateCSV(from dict: [String: String]) -> String {
        var csvContent = "Từ gốc,Thay thế\n"
        let sortedKeys = dict.keys.sorted()
        for key in sortedKeys {
            let val = dict[key] ?? ""
            let escapedKey = key.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedVal = val.replacingOccurrences(of: "\"", with: "\"\"")
            csvContent += "\"\(escapedKey)\",\"\(escapedVal)\"\n"
        }
        return csvContent
    }

    private func importDictionary(from url: URL, hasAccess: Bool) {
        //AppLogger.shared.log("[DEBUG_DICT] ENTER importDictionary")
        isLoading = true
        Task {
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                let fileSize = resourceValues.fileSize ?? 0
                if fileSize <= 0 {
                    throw NSError(domain: "DictionaryEditView", code: 400, userInfo: [NSLocalizedDescriptionKey: "Tệp tin từ điển trống hoặc không hợp lệ."])
                }
                if fileSize > 5_242_880 { // 5MB
                    throw NSError(domain: "DictionaryEditView", code: 413, userInfo: [NSLocalizedDescriptionKey: "Kích thước tệp tin từ điển vượt quá giới hạn 5MB."])
                }
                
                let data = try Data(contentsOf: url)
                let ext = url.pathExtension.lowercased()
                
                var importedWords: [String: String] = [:]
                
                if ext == "plist" {
                    guard let dict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String] else {
                        throw NSError(domain: "DictionaryEditView", code: 400, userInfo: [NSLocalizedDescriptionKey: "Tệp .plist không hợp lệ. Vui lòng chọn tệp chứa định dạng [String: String]."])
                    }
                    importedWords = dict
                } else if ext == "json" {
                    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                    if let dict = jsonObject as? [String: String] {
                        importedWords = dict
                    } else if let dictAny = jsonObject as? [String: Any] {
                        for (key, value) in dictAny {
                            if let stringValue = value as? String {
                                importedWords[key] = stringValue
                            } else if let numberValue = value as? NSNumber {
                                importedWords[key] = numberValue.stringValue
                            } else if let boolValue = value as? Bool {
                                importedWords[key] = String(boolValue)
                            }
                        }
                        if importedWords.isEmpty {
                            throw NSError(domain: "DictionaryEditView", code: 400, userInfo: [NSLocalizedDescriptionKey: "Tệp .json không hợp lệ. Vui lòng chọn tệp chứa dạng cặp khóa-giá trị phẳng [String: String]."])
                        }
                    } else {
                        throw NSError(domain: "DictionaryEditView", code: 400, userInfo: [NSLocalizedDescriptionKey: "Tệp .json không hợp lệ. Vui lòng chọn tệp chứa dạng cặp khóa-giá trị phẳng [String: String]."])
                    }
                } else if ext == "csv" || ext == "txt" {
                    importedWords = try parseCSV(data: data)
                } else {
                    throw NSError(domain: "DictionaryEditView", code: 400, userInfo: [NSLocalizedDescriptionKey: "Định dạng tệp không được hỗ trợ."])
                }
                
                guard let localWordsURL = TextPreprocessor.getWordsURL() else {
                    throw NSError(domain: "DictionaryEditView", code: 500, userInfo: [NSLocalizedDescriptionKey: "Không thể định vị đường dẫn lưu từ điển."])
                }
                
                let plistData = try PropertyListSerialization.data(fromPropertyList: importedWords, format: .xml, options: 0)
                try plistData.write(to: localWordsURL, options: .atomic)
                
                await TextPreprocessor.shared.loadResources()
                await loadDictionary()
                appState.notifyDictionaryChanged()
                
                showToast("Nhập từ điển thành công! Đã cập nhật \(importedWords.count) từ.", isError: false)
            } catch {
                showToast("Lỗi nhập từ điển: \(error.localizedDescription)", isError: true)
            }
            isLoading = false
        }
    }

    private func addWord(key: String, value: String) {
        Task {
            do {
                try await TextPreprocessor.shared.updateWord(key: key, value: value)
                await loadDictionary()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func updateWord(key: String, value: String) {
        Task {
            do {
                try await TextPreprocessor.shared.updateWord(key: key, value: value)
                await loadDictionary()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteWord(key: String) {
        Task {
            do {
                try await TextPreprocessor.shared.deleteWord(key: key)
                await loadDictionary()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct EditingEntry: Identifiable {
    let id: String
    let key: String
    let value: String

    init(key: String, value: String) {
        self.id = key
        self.key = key
        self.value = value
    }
}

@MainActor
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

@MainActor
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
