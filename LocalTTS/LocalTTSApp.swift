import SwiftUI

@main
struct LocalTTSApp: App {
    @StateObject private var appState = AppState()

    init() {
        UserDefaults.standard.register(defaults: [
            "newlinePauseDuration": 0.5,
            "sentencePauseDuration": 0.4,
            "phrasePauseDuration": 0.15
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
