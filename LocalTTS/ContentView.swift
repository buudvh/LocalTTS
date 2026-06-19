import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var voices: [Voice] = []
    @State private var isLoadingVoices = false
    @State private var selectedVoice = NghiTTSClient.defaultVietnameseVoice
    @State private var prefetchStatus = ""

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

                Section("Engine") {
                    Text(appState.ttsService.engineStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
}
