import SwiftUI
import AVFoundation

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

                    Button("Prefetch Selected Model") {
                        Task { await prefetchSelectedVoice() }
                    }

                    if !prefetchStatus.isEmpty {
                        Text(prefetchStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Test TTS") {
                    TextField("Text to synthesize", text: $testText, axis: .vertical)
                        .lineLimit(1...5)
                    
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
            .navigationTitle("LocalTTS")
            .task {
                appState.startServer()
                await loadVoices(forceRefresh: false)
            }
            .sheet(isPresented: $isShowingLogs) {
                LogView()
            }
        }
    }

    private func loadVoices(forceRefresh: Bool) async {
        isLoadingVoices = true
        defer { isLoadingVoices = false }

        do {
            voices = try await appState.nghiClient.fetchVietnameseVoices(forceRefresh: forceRefresh)
            if !voices.contains(selectedVoice), let first = voices.first {
                selectedVoice = first
            }
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func prefetchSelectedVoice() async {
        prefetchStatus = "Downloading \(selectedVoice.name)..."
        do {
            let result = try await appState.nghiClient.prefetchModels(voices: [selectedVoice.name])
            prefetchStatus = result.first?.message ?? "Done"
        } catch {
            prefetchStatus = error.localizedDescription
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
