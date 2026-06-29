import SwiftUI
import AVFoundation

struct TTSView: View {
    @EnvironmentObject private var appState: AppState
    @State private var voices: [Voice] = []
    @State private var isLoadingVoices = false
    @State private var selectedVoice = NghiTTSClient.defaultVietnameseVoice
    @State private var prefetchStatus = ""
    
    @State private var testText = "Xin chào, đây là thử giọng tiếng Việt."
    @State private var testSpeed = 1.0
    @State private var isSynthesizing = false
    @State private var testAudioPlayer: AVAudioPlayer? = nil
    
    @State private var isDownloadingModel = false
    @State private var downloadProgressValue: Double = 0.0
    @State private var downloadMessage = ""

    var body: some View {
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
            .task {
                await loadVoices(forceRefresh: false)
            }
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
