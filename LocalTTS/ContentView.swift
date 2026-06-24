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
    
    // Tab navigation and refresh trigger
    @State private var activeTab: TabType = .tts
    @State private var modelRefreshTrigger = 0
    
    // Progress variables for model downloading in Model tab
    @State private var downloadingStatus: [String: Double] = [:]
    @State private var downloadingMessages: [String: String] = [:]

    // Voice categorization helpers
    private var topVoices: [Voice] {
        let topNames = ["Ngọc Huyền (mới)", "Mai Phương", "Duy Onyx (mới)", "Ngọc Ngạn"].map { $0.precomposedStringWithCanonicalMapping }
        return NghiTTSClient.fallbackVietnameseVoices.filter { topNames.contains($0.name.precomposedStringWithCanonicalMapping) }
    }

    private var systemVoices: [Voice] {
        let topNames = ["Ngọc Huyền (mới)", "Mai Phương", "Duy Onyx (mới)", "Ngọc Ngạn"].map { $0.precomposedStringWithCanonicalMapping }
        return NghiTTSClient.fallbackVietnameseVoices.filter { !topNames.contains($0.name.precomposedStringWithCanonicalMapping) }
    }

    private var customVoices: [Voice] {
        let _ = modelRefreshTrigger
        let localIDs = appState.modelStore.getLocalVoiceIDs()
        let fallbackIDs = NghiTTSClient.fallbackVietnameseVoices.map { $0.id }
        let customIDs = localIDs.filter { !fallbackIDs.contains($0) }
        return customIDs.map { id in
            let name = id.replacingOccurrences(of: "_", with: " ").capitalized
            return Voice(id: id, name: name)
        }
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $activeTab) {
                // Tab 1: TTS
                Form {
                    Section("NghiTTS Voices") {
                        if isLoadingVoices {
                            ProgressView()
                        }

                        Picker("Voice", selection: $selectedVoice) {
                            ForEach(voices.isEmpty ? [selectedVoice] : voices, id: \.self) { voice in
                                Text(voice.name).tag(voice)
                            }
                        }

                        Button("Refresh Voices") {
                            Task { await loadVoices(forceRefresh: true) }
                        }

                        Button("Prefetch Selected Model") {
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

                    Section("Test TTS") {
                        HStack {
                            TextField("Text to synthesize", text: $testText, axis: .vertical)
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

                        Button(isSynthesizing ? "Synthesizing..." : "Speak") {
                            Task { await testTTS() }
                        }
                        .disabled(isSynthesizing || testText.trimmed.isEmpty)
                    }
                }
                .tabItem {
                    Label("TTS", systemImage: "waveform.and.mic")
                }
                .tag(TabType.tts)
                
                // Tab 2: Model (Quản lý Model)
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
                .tabItem {
                    Label("Model", systemImage: "arrow.down.circle")
                }
                .tag(TabType.model)

                // Tab 3: Từ điển (Màn hình Xóa/Sửa từ trực tiếp)
                DictionaryEditView()
                    .tabItem {
                        Label("Từ điển", systemImage: "character.book.closed")
                    }
                    .tag(TabType.dictionary)
                
                // Tab 4: Hệ thống
                Form {
                    let hasNoModels = appState.modelStore.getLocalVoiceIDs().isEmpty
                    let hasNoDictionary = !FileManager.default.fileExists(atPath: appState.modelStore.rootURL.appendingPathComponent("non-vietnamese-words.plist").path) || !FileManager.default.fileExists(atPath: appState.modelStore.rootURL.appendingPathComponent("acronyms.plist").path)

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
                    }

                    Section("Server") {
                        HStack {
                            Text(appState.server.isRunning ? "Running" : "Stopped")
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

                        Button(appState.server.isRunning ? "Stop Server" : "Start Server") {
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
                        Button("View Logs") {
                            shareLogFolder()
                        }
                    }

                    if let error = appState.lastError {
                        Section("Error") {
                            Text(error)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .tabItem {
                    Label("Hệ thống", systemImage: "server.rack")
                }
                .tag(TabType.system)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("LocalTTS")
            .task {
                appState.startServer()
                await loadVoices(forceRefresh: false)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    Task {
                        await importModels(from: urls)
                    }
                case .failure(let error):
                    appState.lastError = "Import failed: \(error.localizedDescription)"
                }
            }
        }
        .dismissKeyboardOnTap()
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
            Task {
                await loadVoices(forceRefresh: false)
            }
        } catch {
            appState.lastError = "Lỗi xóa model \(voice.name): \(error.localizedDescription)"
        }
    }

    private func shareLogFolder() {
        let logFolderURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        #if canImport(UIKit)
        let activityVC = UIActivityViewController(activityItems: [logFolderURL], applicationActivities: nil)
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

    private func importModels(from urls: [URL]) async {
        let fm = FileManager.default
        var importCount = 0
        var errorCount = 0
        
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer {
                if access {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            let ext = url.pathExtension.lowercased()
            let filename = url.lastPathComponent
            
            do {
                let targetURL: URL
                if ext == "onnx" {
                    let voiceId = url.deletingPathExtension().lastPathComponent.toASCIIID
                    targetURL = appState.modelStore.modelURL(for: voiceId, extension: "onnx")
                } else if ext == "json" {
                    let baseName = url.deletingPathExtension().lastPathComponent
                    let voiceId: String
                    if baseName.lowercased().hasSuffix(".onnx") {
                        voiceId = String(baseName.dropLast(5)).toASCIIID
                    } else {
                        voiceId = baseName.toASCIIID
                    }
                    targetURL = appState.modelStore.modelURL(for: voiceId, extension: "onnx.json")
                } else {
                    continue
                }
                
                if fm.fileExists(atPath: targetURL.path) {
                    try fm.removeItem(at: targetURL)
                }
                
                try fm.copyItem(at: url, to: targetURL)
                importCount += 1
            } catch {
                appLog("Failed to import file \(filename): \(error.localizedDescription)")
                errorCount += 1
            }
        }
        
        appLog("Imported \(importCount) files. Errors: \(errorCount)")
        modelRefreshTrigger += 1
        await loadVoices(forceRefresh: false)
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
                Section("Preprocess") {
                    Toggle("Normalize numbers", isOn: $preprocessorNumericNormalizationEnabled)
                    Toggle("Replace dictionary words", isOn: $preprocessorDictionaryReplacementEnabled)
                    Toggle("Transliterate EN/JP", isOn: $preprocessorTransliterationEnabled)
                    Toggle("Debug preprocess logs", isOn: $preprocessorDebugLoggingEnabled)
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
    
    @State private var showingFileImporter = false
    @State private var showingDownloadConfirmation = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""

    var filteredKeys: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return Array(sortedKeys.prefix(100))
        } else {
            var matches: [String] = []
            for key in sortedKeys {
                if key.contains(query) {
                    matches.append(key)
                    if matches.count >= 100 {
                        break
                    }
                }
            }
            return matches
        }
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
                            Text("Hiển thị 100 từ đầu tiên. Nhập từ khóa để tìm kiếm các từ khác.")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                        }
                    } header: {
                        Text("Từ vựng (\(allWords.count) từ)")
                    }
                }
                .searchable(text: $searchText, prompt: "Tìm từ...")
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
                    if let exportURL = exportURL {
                        ShareLink(item: exportURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    Button {
                        showingFileImporter = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Button {
                        showingDownloadConfirmation = true
                    } label: {
                        Image(systemName: "arrow.down.to.line")
                    }
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddWordSheet(onAdd: { key, val in
                addWord(key: key, value: val)
            })
        }
        .sheet(item: Binding(
            get: { editingKey.map { EditingEntry(key: $0, value: editingValue) } },
            set: { editingKey = $0?.key; editingValue = $0?.value ?? "" }
        )) { entry in
            EditWordSheet(key: entry.key, value: entry.value) { newVal in
                updateWord(key: entry.key, value: newVal)
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.propertyList],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let selectedURL = urls.first else { return }
                importDictionary(from: selectedURL)
            case .failure(let error):
                self.errorMessage = "Lỗi chọn tệp: \(error.localizedDescription)"
            }
        }
        .alert("Xác nhận tải lại", isPresented: $showingDownloadConfirmation) {
            Button("Hủy", role: .cancel) {}
            Button("Tải lại", role: .destructive) {
                downloadDictionaries()
            }
        } message: {
            Text("Hành động này sẽ tải lại từ điển gốc từ HuggingFace và ghi đè tất cả các từ vựng tùy chỉnh bạn đã thêm. Bạn có chắc chắn muốn tiếp tục?")
        }
        .alert("Thành công", isPresented: $showingSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage)
        }
        .alert("Lỗi", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .task {
            await loadDictionary()
        }
    }

    private func loadDictionary() async {
        isLoading = true
        let map = await TextPreprocessor.shared.getWordMap()
        allWords = map
        sortedKeys = map.keys.sorted()
        exportURL = TextPreprocessor.getWordsURL()
        isLoading = false
    }

    private func downloadDictionaries() {
        isLoading = true
        Task {
            do {
                try await appState.nghiClient.downloadDictionaries()
                await loadDictionary()
                successMessage = "Tải từ điển từ HuggingFace thành công!"
                showingSuccessAlert = true
            } catch {
                errorMessage = "Không thể tải từ điển: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func importDictionary(from url: URL) {
        isLoading = true
        Task {
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    throw NSError(domain: "DictionaryEditView", code: 403, userInfo: [NSLocalizedDescriptionKey: "Không có quyền truy cập tệp đã chọn."])
                }
                defer { url.stopAccessingSecurityScopedResource() }
                
                let data = try Data(contentsOf: url)
                guard let plistDict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: String] else {
                    throw NSError(domain: "DictionaryEditView", code: 400, userInfo: [NSLocalizedDescriptionKey: "Tệp không hợp lệ. Vui lòng chọn tệp .plist chứa định dạng [String: String]."])
                }
                
                guard let localWordsURL = TextPreprocessor.getWordsURL() else {
                    throw NSError(domain: "DictionaryEditView", code: 500, userInfo: [NSLocalizedDescriptionKey: "Không thể định vị đường dẫn lưu từ điển."])
                }
                
                try data.write(to: localWordsURL, options: .atomic)
                await TextPreprocessor.shared.loadResources()
                await loadDictionary()
                
                successMessage = "Nhập từ điển thành công! Đã cập nhật \(plistDict.count) từ."
                showingSuccessAlert = true
            } catch {
                errorMessage = "Lỗi nhập từ điển: \(error.localizedDescription)"
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
                        .onChange(of: key) { newValue in
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
