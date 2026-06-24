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
        let localAcronyms = modelStore.rootURL.appendingPathComponent("acronyms.plist")
        let localWords = modelStore.rootURL.appendingPathComponent("non-vietnamese-words.plist")
        
        let currentVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") + "-" + (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "")
        let lastVersion = UserDefaults.standard.string(forKey: "LastInstalledVersion") ?? ""
        
        var shouldCopy = false
        if !fm.fileExists(atPath: localAcronyms.path) || !fm.fileExists(atPath: localWords.path) || currentVersion != lastVersion {
            shouldCopy = true
        } else {
            if let bundleAcronymsURL = Bundle.main.url(forResource: "acronyms", withExtension: "plist"),
               let bundleWordsURL = Bundle.main.url(forResource: "non-vietnamese-words", withExtension: "plist") {
                let localAcronymsSize = (try? fm.attributesOfItem(atPath: localAcronyms.path)[.size] as? UInt64) ?? 0
                let bundleAcronymsSize = (try? fm.attributesOfItem(atPath: bundleAcronymsURL.path)[.size] as? UInt64) ?? 0
                let localWordsSize = (try? fm.attributesOfItem(atPath: localWords.path)[.size] as? UInt64) ?? 0
                let bundleWordsSize = (try? fm.attributesOfItem(atPath: bundleWordsURL.path)[.size] as? UInt64) ?? 0
                
                if localAcronymsSize != bundleAcronymsSize || localWordsSize != bundleWordsSize {
                    shouldCopy = true
                }
            }
        }
        
        if forceRefresh || shouldCopy {
            do {
                try await copyDictionaryPlistsFromBundle()
                UserDefaults.standard.set(currentVersion, forKey: "LastInstalledVersion")
            } catch {
                appLog("Warning: Failed to copy plist files: \(error.localizedDescription)")
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

    func copyDictionaryPlistsFromBundle() async throws {
        // Copy acronyms.plist and non-vietnamese-words.plist directly from main Bundle to the modelStore directory.
        let localAcronyms = modelStore.rootURL.appendingPathComponent("acronyms.plist")
        let localWords = modelStore.rootURL.appendingPathComponent("non-vietnamese-words.plist")
        let fm = FileManager.default
        
        guard let bundleAcronymsURL = Bundle.main.url(forResource: "acronyms", withExtension: "plist") else {
            throw NSError(domain: "NghiTTSClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "acronyms.plist not found in app bundle"])
        }
        
        guard let bundleWordsURL = Bundle.main.url(forResource: "non-vietnamese-words", withExtension: "plist") else {
            throw NSError(domain: "NghiTTSClient", code: 404, userInfo: [NSLocalizedDescriptionKey: "non-vietnamese-words.plist not found in app bundle"])
        }
        
        try fm.createDirectory(at: modelStore.rootURL, withIntermediateDirectories: true)
        
        if fm.fileExists(atPath: localAcronyms.path) {
            try fm.removeItem(at: localAcronyms)
        }
        try fm.copyItem(at: bundleAcronymsURL, to: localAcronyms)
        if let attr = try? fm.attributesOfItem(atPath: bundleAcronymsURL.path), let size = attr[.size] as? UInt64 {
            UserDefaults.standard.set(Int(size), forKey: "lastSyncedAcronymsSize")
        }
        
        if fm.fileExists(atPath: localWords.path) {
            try fm.removeItem(at: localWords)
        }
        try fm.copyItem(at: bundleWordsURL, to: localWords)
        if let attr = try? fm.attributesOfItem(atPath: bundleWordsURL.path), let size = attr[.size] as? UInt64 {
            UserDefaults.standard.set(Int(size), forKey: "lastSyncedWordsSize")
        }
        
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
