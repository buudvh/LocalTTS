import SwiftUI

enum TabType: Hashable {
    case tts
    case model
    case dictionary
    case system
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var activeTab: TabType = .tts
    @State private var systemTabRefreshTrigger = 0

    var body: some View {
        ZStack {
            TabView(selection: $activeTab) {
                TTSView()
                    .tabItem {
                        Label("TTS", systemImage: "waveform.and.mic")
                    }
                    .tag(TabType.tts)

                ModelManagerView()
                    .tabItem {
                        Label("Model", systemImage: "arrow.down.circle")
                    }
                    .tag(TabType.model)

                NavigationStack {
                    DictionaryEditView()
                }
                .tabItem {
                    Label("Từ điển", systemImage: "character.book.closed")
                }
                .tag(TabType.dictionary)

                SystemView(activeTab: $activeTab)
                    .tabItem {
                        Label("Hệ thống", systemImage: "server.rack")
                    }
                    .tag(TabType.system)
                    .id(systemTabRefreshTrigger)
            }
            .onChange(of: activeTab) { oldValue, newValue in
                if newValue == .system {
                    systemTabRefreshTrigger += 1
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .task {
                appState.startServer()
            }
            .dismissKeyboardOnTap()
        }
    }
}
