import Foundation

final class NghiTTSClient {
    static let defaultVietnameseVoice = Voice(name: "Ngọc Huyền (mới)")
    static let fallbackVietnameseVoices = [
        Voice(name: "Ngọc Huyền (mới)"),
        Voice(name: "Mai Phương"),
        Voice(name: "Duy Onyx (mới)"),
        Voice(name: "Ngọc Ngạn"),
        Voice(name: "Ban Mai"),
        Voice(name: "Chiếu Thành"),
        Voice(name: "Duy Oryx"),
        Voice(name: "Lạc Phi"),
        Voice(name: "Minh Khang"),
        Voice(name: "Minh Quang"),
        Voice(name: "Mạnh Dũng"),
        Voice(name: "Mỹ Tâm"),
        Voice(name: "Mỹ Tâm Real"),
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

    private let baseURL = URL(string: "https://huggingface.co/raikiri1498/nghitts/resolve/main")!
    private let session: URLSession
    private let modelStore: ModelStore

    init(modelStore: ModelStore, session: URLSession = .shared) {
        self.modelStore = modelStore
        self.session = session
    }

    func fetchVietnameseVoices(forceRefresh: Bool) async throws -> [Voice] {
        let fm = FileManager.default
        let localWords = modelStore.rootURL.appendingPathComponent("non-vietnamese-words.plist")
        
        let currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") + "-" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "")
        let lastVersion = UserDefaults.standard.string(forKey: "LastInstalledVersion") ?? ""
        
        var shouldDownload = false
        if !fm.fileExists(atPath: localWords.path) || currentVersion != lastVersion {
            shouldDownload = true
        }
        
        if forceRefresh || shouldDownload {
            do {
                try await downloadDictionaries()
                UserDefaults.standard.set(currentVersion, forKey: "LastInstalledVersion")
            } catch {
                appLog("Warning: Failed to download dictionary files: \(error.localizedDescription)")
            }
        }

        if !forceRefresh, let cached = modelStore.readCachedVoices(), !cached.isEmpty {
            return cached.map { Voice(name: $0.precomposedStringWithCanonicalMapping) }
        }

        do {
            let url = baseURL.appendingPathComponent("models.json")
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
        let allowedNames = ["Ngọc Huyền (mới)", "Mai Phương", "Duy Onyx (mới)", "Ngọc Ngạn"].map { $0.precomposedStringWithCanonicalMapping }
        var filteredVoices: [Voice] = []
        
        for voice in Self.fallbackVietnameseVoices {
            let normalizedName = voice.name.precomposedStringWithCanonicalMapping
            if allowedNames.contains(normalizedName) {
                filteredVoices.append(voice)
            }
        }
        
        let localVoiceIds = modelStore.getLocalVoiceIDs()
        for voiceId in localVoiceIds {
            if !filteredVoices.contains(where: { $0.id == voiceId }) {
                let displayName = voiceId.replacingOccurrences(of: "_", with: " ").capitalized
                filteredVoices.append(Voice(id: voiceId, name: displayName))
            }
        }
        return filteredVoices
    }

    func getModelList() -> [Voice] {
        var allVoices = Self.fallbackVietnameseVoices
        let localVoiceIds = modelStore.getLocalVoiceIDs()
        for voiceId in localVoiceIds {
            if !allVoices.contains(where: { $0.id == voiceId }) {
                let displayName = voiceId.replacingOccurrences(of: "_", with: " ").capitalized
                allVoices.append(Voice(id: voiceId, name: displayName))
            }
        }
        return allVoices
    }


    func downloadDictionaries() async throws {
        let fm = FileManager.default
        let localAcronyms = modelStore.rootURL.appendingPathComponent("acronyms.plist")
        let localWords = modelStore.rootURL.appendingPathComponent("non-vietnamese-words.plist")
        
        let acronymsURL = baseURL.appendingPathComponent("acronyms.plist")
        let wordsURL = baseURL.appendingPathComponent("non-vietnamese-words.plist")
        
        // Download acronyms.plist
        let (acronymsData, responseAcronyms) = try await session.data(from: acronymsURL)
        try Self.validateHTTP(responseAcronyms)
        
        guard (try? PropertyListSerialization.propertyList(from: acronymsData, options: [], format: nil) as? [String: String]) != nil else {
            throw NSError(domain: "NghiTTSClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu acronyms.plist không hợp lệ"])
        }
        
        // Download non-vietnamese-words.plist
        let (wordsData, responseWords) = try await session.data(from: wordsURL)
        try Self.validateHTTP(responseWords)
        
        guard (try? PropertyListSerialization.propertyList(from: wordsData, options: [], format: nil) as? [String: String]) != nil else {
            throw NSError(domain: "NghiTTSClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu non-vietnamese-words.plist không hợp lệ"])
        }
        
        // Save files
        try fm.createDirectory(at: modelStore.rootURL, withIntermediateDirectories: true)
        try acronymsData.write(to: localAcronyms, options: .atomic)
        try wordsData.write(to: localWords, options: .atomic)
        
        // Reload resources in preprocessor
        await TextPreprocessor.shared.loadResources()
    }

    func prefetchModels(voices: [String], progressHandler: ((String, Double) -> Void)? = nil) async throws -> [PrefetchResult] {
        let bgSession = BackgroundTaskSession.begin(name: "LocalTTS-DownloadModel")
        defer { bgSession.end() }
        
        let totalFiles = voices.count * 2
        var completedFiles = 0
        
        var results: [PrefetchResult] = []
        for rawVoice in voices {
            let voice = Voice(name: rawVoice.precomposedStringWithCanonicalMapping)
            let onnxURL = try remoteModelURL(for: voice.id, fileExtension: "onnx")
            let configURL = try remoteModelURL(for: voice.id, fileExtension: "onnx.json")
            let localOnnx = modelStore.modelURL(for: voice.id, extension: "onnx")
            let localConfig = modelStore.modelURL(for: voice.id, extension: "onnx.json")

            if !FileManager.default.fileExists(atPath: localOnnx.path) {
                progressHandler?("Đang tải \(voice.name).onnx...", Double(completedFiles) / Double(totalFiles))
                try await download(from: onnxURL, to: localOnnx)
            }
            completedFiles += 1
            progressHandler?("Đã tải \(voice.name).onnx", Double(completedFiles) / Double(totalFiles))

            if !FileManager.default.fileExists(atPath: localConfig.path) {
                progressHandler?("Đang tải cấu hình \(voice.name)...", Double(completedFiles) / Double(totalFiles))
                try await download(from: configURL, to: localConfig)
            }
            completedFiles += 1
            progressHandler?("Đã tải cấu hình \(voice.name)", Double(completedFiles) / Double(totalFiles))

            results.append(PrefetchResult(
                voice: voice.name,
                onnxCached: FileManager.default.fileExists(atPath: localOnnx.path),
                configCached: FileManager.default.fileExists(atPath: localConfig.path),
                bytes: modelStore.bytesForVoice(voice.id),
                message: "Cached \(voice.name)"
            ))
        }
        progressHandler?("Tải hoàn tất!", 1.0)
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

    private func remoteModelURL(for voice: String, fileExtension ext: String) throws -> URL {
        guard let encodedVoice = voice.addingPercentEncoding(withAllowedCharacters: .urlPathComponentAllowedStrict) else {
            throw APIError.badRequest("Invalid voice name: \(voice)")
        }
        let baseStr = baseURL.absoluteString
        let urlStr = baseStr.hasSuffix("/") ? "\(baseStr)\(encodedVoice).\(ext)" : "\(baseStr)/\(encodedVoice).\(ext)"
        guard let url = URL(string: urlStr) else {
            throw APIError.badRequest("Invalid URL for voice: \(voice)")
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
