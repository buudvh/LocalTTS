import Foundation

final class NghiTTSClient {
    static let defaultVietnameseVoice = Voice(name: "Ngọc Huyền (mới)")
    static let fallbackVietnameseVoices = [
        Voice(name: "Ban Mai"),
        Voice(name: "Chiếu Thành"),
        Voice(name: "Duy Onyx (mới)"),
        Voice(name: "Duy Oryx"),
        Voice(name: "Lạc Phi"),
        Voice(name: "Mai Phương"),
        Voice(name: "Minh Khang"),
        Voice(name: "Minh Quang"),
        Voice(name: "Mạnh Dũng"),
        Voice(name: "Mỹ Tâm"),
        Voice(name: "Mỹ Tâm Real"),
        Voice(name: "Ngọc Huyền (mới)"),
        Voice(name: "Ngọc Ngạn"),
        Voice(name: "Phương Trang"),
        Voice(name: "Thanh Phương Viettel"),
        Voice(name: "Thiện Tâm"),
        Voice(name: "Trấn Thành"),
        Voice(name: "Tài An"),
        Voice(name: "Việt Thảo"),
        Voice(name: "adam")
    ]

    private struct ModelsResponse: Codable {
        let models: [String]
    }

    private let baseURL = URL(string: "https://nghitts.app")!
    private let session: URLSession
    private let modelStore: ModelStore

    init(modelStore: ModelStore, session: URLSession = .shared) {
        self.modelStore = modelStore
        self.session = session
    }

    func fetchVietnameseVoices(forceRefresh: Bool) async throws -> [Voice] {
        let fm = FileManager.default
        let localWords = modelStore.rootURL.appendingPathComponent("non-vietnamese-words.csv")
        let localAcronyms = modelStore.rootURL.appendingPathComponent("acronyms.csv")
        if forceRefresh || !fm.fileExists(atPath: localWords.path) || !fm.fileExists(atPath: localAcronyms.path) {
            do {
                try await downloadCSVFiles()
            } catch {
                appLog("Warning: Failed to download CSV files: \(error.localizedDescription)")
            }
        }

        if !forceRefresh, let cached = modelStore.readCachedVoices(), !cached.isEmpty {
            return cached.map { Voice(name: $0.precomposedStringWithCanonicalMapping) }
        }

        do {
            let url = baseURL.appendingPathComponent("api/piper/vi/models")
            let (data, response) = try await session.data(from: url)
            try Self.validateHTTP(response)
            let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
            let normalizedVoices = decoded.models.map { $0.precomposedStringWithCanonicalMapping }
            try modelStore.writeCachedVoices(normalizedVoices)
            return normalizedVoices.map { Voice(name: $0) }
        } catch {
            if let cached = modelStore.readCachedVoices(), !cached.isEmpty {
                return cached.map { Voice(name: $0.precomposedStringWithCanonicalMapping) }
            }
            return Self.fallbackVietnameseVoices
        }
    }

    func getAllVoices(forceRefresh: Bool = false) async throws -> [Voice] {
        let remoteVoices = try await fetchVietnameseVoices(forceRefresh: forceRefresh)
        let localVoiceIds = modelStore.getLocalVoiceIDs()
        var allVoices = remoteVoices
        
        for voiceId in localVoiceIds {
            if !allVoices.contains(where: { $0.id == voiceId }) {
                let displayName = voiceId.replacingOccurrences(of: "_", with: " ").capitalized
                allVoices.append(Voice(id: voiceId, name: displayName))
            }
        }
        return allVoices
    }

    func downloadCSVFiles() async throws {
        let bgSession = BackgroundTaskSession.begin(name: "LocalTTS-DownloadCSV")
        defer { bgSession.end() }
        
        let wordsURL = baseURL.appendingPathComponent("data/non-vietnamese-words.csv")
        let acronymsURL = baseURL.appendingPathComponent("data/acronyms.csv")
        
        let localWords = modelStore.rootURL.appendingPathComponent("non-vietnamese-words.csv")
        let localAcronyms = modelStore.rootURL.appendingPathComponent("acronyms.csv")
        
        var requestWords = URLRequest(url: wordsURL)
        requestWords.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36 Edg/149.0.0.0", forHTTPHeaderField: "User-Agent")
        requestWords.setValue("https://nghitts.app/assets/tts-worker-CWObADHY.js", forHTTPHeaderField: "Referer")
        
        let (tempWordsURL, responseWords) = try await session.download(for: requestWords)
        try Self.validateHTTP(responseWords)
        
        var requestAcronyms = URLRequest(url: acronymsURL)
        requestAcronyms.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36 Edg/149.0.0.0", forHTTPHeaderField: "User-Agent")
        requestAcronyms.setValue("https://nghitts.app/assets/tts-worker-CWObADHY.js", forHTTPHeaderField: "Referer")
        
        let (tempAcronymsURL, responseAcronyms) = try await session.download(for: requestAcronyms)
        try Self.validateHTTP(responseAcronyms)
        
        let fm = FileManager.default
        try fm.createDirectory(at: modelStore.rootURL, withIntermediateDirectories: true)
        
        if fm.fileExists(atPath: localWords.path) {
            try fm.removeItem(at: localWords)
        }
        try fm.moveItem(at: tempWordsURL, to: localWords)
        
        if fm.fileExists(atPath: localAcronyms.path) {
            try fm.removeItem(at: localAcronyms)
        }
        try fm.moveItem(at: tempAcronymsURL, to: localAcronyms)
        
        TextPreprocessor.shared.loadResources()
    }

    func prefetchModels(voices: [String]) async throws -> [PrefetchResult] {
        let bgSession = BackgroundTaskSession.begin(name: "LocalTTS-DownloadModel")
        defer { bgSession.end() }
        
        var results: [PrefetchResult] = []
        for rawVoice in voices {
            let voice = Voice(name: rawVoice.precomposedStringWithCanonicalMapping)
            let onnxURL = try remoteModelURL(for: voice.name, extension: "onnx")
            let configURL = try remoteModelURL(for: voice.name, extension: "onnx.json")
            let localOnnx = modelStore.modelURL(for: voice.id, extension: "onnx")
            let localConfig = modelStore.modelURL(for: voice.id, extension: "onnx.json")

            if !FileManager.default.fileExists(atPath: localOnnx.path) {
                try await download(from: onnxURL, to: localOnnx)
            }

            if !FileManager.default.fileExists(atPath: localConfig.path) {
                try await download(from: configURL, to: localConfig)
            }

            results.append(PrefetchResult(
                voice: voice.name,
                onnxCached: FileManager.default.fileExists(atPath: localOnnx.path),
                configCached: FileManager.default.fileExists(atPath: localConfig.path),
                bytes: modelStore.bytesForVoice(voice.id),
                message: "Cached \(voice.name)"
            ))
        }
        return results
    }

    private func download(from remoteURL: URL, to localURL: URL) async throws {
        let (tempURL, response) = try await session.download(from: remoteURL)
        try Self.validateHTTP(response)

        let parent = localURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: localURL)
    }

    private func remoteModelURL(for voice: String, extension ext: String) throws -> URL {
        guard let encodedVoice = voice.addingPercentEncoding(withAllowedCharacters: .urlPathComponentAllowedStrict),
              let url = URL(string: "api/model/\(encodedVoice).\(ext)", relativeTo: baseURL)?.absoluteURL else {
            throw APIError.badRequest("Invalid voice name: \(voice)")
        }
        return url
    }

    private static func validateHTTP(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.upstream("NGHI-TTS returned HTTP \(http.statusCode)")
        }
    }
}

private extension CharacterSet {
    static let urlPathComponentAllowedStrict = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}
