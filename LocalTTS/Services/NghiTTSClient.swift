import Foundation

final class NghiTTSClient {
    static let defaultVietnameseVoice = "Ngọc Huyền (mới)"
    static let fallbackVietnameseVoices = [
        "Ban Mai",
        "Chiếu Thành",
        "Duy Onyx (mới)",
        "Duy Oryx",
        "Lạc Phi",
        "Mai Phương",
        "Minh Khang",
        "Minh Quang",
        "Mạnh Dũng",
        "Mỹ Tâm",
        "Mỹ Tâm Real",
        "Ngọc Huyền (mới)",
        "Ngọc Ngạn",
        "Phương Trang",
        "Thanh Phương Viettel",
        "Thiện Tâm",
        "Trấn Thành",
        "Tài An",
        "Việt Thảo",
        "adam"
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

    func fetchVietnameseVoices(forceRefresh: Bool) async throws -> [String] {
        if !forceRefresh, let cached = modelStore.readCachedVoices(), !cached.isEmpty {
            return cached.map { $0.precomposedStringWithCanonicalMapping }
        }

        do {
            let url = baseURL.appendingPathComponent("api/piper/vi/models")
            let (data, response) = try await session.data(from: url)
            try Self.validateHTTP(response)
            let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
            let normalizedVoices = decoded.models.map { $0.precomposedStringWithCanonicalMapping }
            try modelStore.writeCachedVoices(normalizedVoices)
            return normalizedVoices
        } catch {
            if let cached = modelStore.readCachedVoices(), !cached.isEmpty {
                return cached.map { $0.precomposedStringWithCanonicalMapping }
            }
            return Self.fallbackVietnameseVoices.map { $0.precomposedStringWithCanonicalMapping }
        }
    }

    func prefetchModels(voices: [String]) async throws -> [PrefetchResult] {
        var results: [PrefetchResult] = []
        for rawVoice in voices {
            let voice = rawVoice.precomposedStringWithCanonicalMapping
            let onnxURL = try remoteModelURL(for: voice, extension: "onnx")
            let configURL = try remoteModelURL(for: voice, extension: "onnx.json")
            let localOnnx = modelStore.modelURL(for: voice, extension: "onnx")
            let localConfig = modelStore.modelURL(for: voice, extension: "onnx.json")

            if !FileManager.default.fileExists(atPath: localOnnx.path) {
                try await download(from: onnxURL, to: localOnnx)
            }

            if !FileManager.default.fileExists(atPath: localConfig.path) {
                try await download(from: configURL, to: localConfig)
            }

            results.append(PrefetchResult(
                voice: voice,
                onnxCached: FileManager.default.fileExists(atPath: localOnnx.path),
                configCached: FileManager.default.fileExists(atPath: localConfig.path),
                bytes: modelStore.bytesForVoice(voice),
                message: "Cached \(voice)"
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
