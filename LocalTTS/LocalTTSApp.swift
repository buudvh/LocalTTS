import SwiftUI

@main
struct LocalTTSApp: App {
    @StateObject private var appState = AppState()

    init() {
        UserDefaults.standard.register(defaults: [
            "newlinePauseDuration": 0.4,
            "sentencePauseDuration": 0.3,
            "phrasePauseDuration": 0.15,
            "bracketPauseDuration": 0.1,
            PreprocessorSettingKey.numericNormalizationEnabled: true,
            PreprocessorSettingKey.dictionaryReplacementEnabled: true,
            PreprocessorSettingKey.transliterationEnabled: true,
            PreprocessorSettingKey.debugLoggingEnabled: false
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
