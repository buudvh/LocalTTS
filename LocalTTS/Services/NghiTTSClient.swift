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

    func prefetchModels(voices: [String]) async throws -> [PrefetchResult] {
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
