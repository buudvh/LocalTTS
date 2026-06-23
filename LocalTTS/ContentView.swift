import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var voices: [Voice] = []
    @State private var isLoadingVoices = false
    @State private var selectedVoice = NghiTTSClient.defaultVietnameseVoice
    @State private var prefetchStatus = ""
    @State private var isShowingLogs = false
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
    
    @AppStorage("newlinePauseDuration") private var newlinePause = 0.5
    @AppStorage("sentencePauseDuration") private var sentencePause = 0.4
    @AppStorage("phrasePauseDuration") private var phrasePause = 0.15
    @AppStorage("bracketPauseDuration") private var bracketPause = 0.15

    var body: some View {
        NavigationStack {
            Form {
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

                    Button("Nhập Model Ngoài...") {
                        isShowingFileImporter = true
                    }

                    Button("Prefetch Selected Model") {
                        Task { await prefetchSelectedVoice() }
                    }
                    .disabled(isDownloadingModel || isLoadingVoices)

                    let uncached = voices.filter { !appState.modelStore.modelExists(for: $0.id) }
                    if !uncached.isEmpty {
                        Button(isDownloadingModel ? "Đang tải các Model..." : "Tải tất cả các Model (\(uncached.count))") {
                            Task { await downloadAllModels(uncached) }
                        }
                        .disabled(isDownloadingModel)
                    }

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

                    /*
                    Button("Cài đặt lại từ điển từ Bundle") {
                        Task {
                            prefetchStatus = "Đang sao chép từ điển..."
                            do {
                                try await appState.nghiClient.copyDictionaryPlistsFromBundle()
                                prefetchStatus = "Cài đặt lại từ điển thành công!"
                            } catch {
                                prefetchStatus = "Lỗi cài đặt từ điển: \(error.localizedDescription)"
                            }
                        }
                    }

                    if !prefetchStatus.isEmpty {
                        Text(prefetchStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    */
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

                Section("Engine") {
                    Text(appState.ttsService.engineStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Logs") {
                    Button("View Logs") {
                        isShowingLogs = true
                    }
                }

                if let error = appState.lastError {
                    Section("Error") {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("LocalTTS")
            .task {
                appState.startServer()
                await loadVoices(forceRefresh: false)
            }
            .sheet(isPresented: $isShowingLogs) {
                LogView()
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
        } catch {
            prefetchStatus = "Lỗi: \(error.localizedDescription)"
        }
    }

    private func downloadAllModels(_ uncached: [Voice]) async {
        isDownloadingModel = true
        downloadProgressValue = 0.0
        downloadMessage = "Bắt đầu tải..."
        prefetchStatus = ""
        defer { isDownloadingModel = false }
        
        let voiceNames = uncached.map { $0.name }
        do {
            _ = try await appState.nghiClient.prefetchModels(voices: voiceNames) { msg, progress in
                DispatchQueue.main.async {
                    self.downloadMessage = msg
                    self.downloadProgressValue = progress
                }
            }
            prefetchStatus = "Đã tải xong toàn bộ \(uncached.count) model!"
        } catch {
            prefetchStatus = "Lỗi tải hàng loạt: \(error.localizedDescription)"
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

struct LogView: View {
    @Environment(\.dismiss) var dismiss
    @State private var logText = ""
    @State private var timer: Timer? = nil

    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    Text(logText.isEmpty ? "No logs yet." : logText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                
                HStack {
                    Button("Clear Logs", role: .destructive) {
                        AppLogger.shared.clearLogs()
                        logText = AppLogger.shared.getLogs()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                    
                    Button("Refresh") {
                        logText = AppLogger.shared.getLogs()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                logText = AppLogger.shared.getLogs()
                // Auto-refresh every 2 seconds
                timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                    logText = AppLogger.shared.getLogs()
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
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
