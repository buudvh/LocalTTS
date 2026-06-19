import Foundation
import CryptoKit


final class ModelStore {
    private let fileManager: FileManager
    let rootURL: URL
    let modelsURL: URL
    private let voicesCacheURL: URL

    init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        self.rootURL = appSupport.appendingPathComponent("LocalTTS", isDirectory: true)
        self.modelsURL = rootURL.appendingPathComponent("Models", isDirectory: true)
        self.voicesCacheURL = rootURL.appendingPathComponent("voices.json")
        try fileManager.createDirectory(at: modelsURL, withIntermediateDirectories: true)
    }

    func cacheSummary() -> CacheSummary {
        let files = (try? fileManager.contentsOfDirectory(
            at: modelsURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let totalBytes = files.reduce(Int64(0)) { partial, url in
            let size = ((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize) ?? 0
            return partial + Int64(size)
        }

        let modelCount = files.filter { $0.pathExtension == "onnx" }.count
        return CacheSummary(
            voicesCached: fileManager.fileExists(atPath: voicesCacheURL.path),
            modelCount: modelCount,
            totalBytes: totalBytes
        )
    }

    func readCachedVoices() -> [String]? {
        guard let data = try? Data(contentsOf: voicesCacheURL) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }

    func writeCachedVoices(_ voices: [String]) throws {
        let data = try JSONEncoder().encode(voices)
        try data.write(to: voicesCacheURL, options: [.atomic])
    }

    func modelURL(for voice: String, extension ext: String) -> URL {
        modelsURL.appendingPathComponent(Self.cacheKey(for: voice)).appendingPathExtension(ext)
    }

    func modelExists(for voice: String) -> Bool {
        fileManager.fileExists(atPath: modelURL(for: voice, extension: "onnx").path)
            && fileManager.fileExists(atPath: modelURL(for: voice, extension: "onnx.json").path)
    }

    func bytesForVoice(_ voice: String) -> Int64 {
        ["onnx", "onnx.json"].reduce(Int64(0)) { partial, ext in
            let url = modelURL(for: voice, extension: ext)
            let size = ((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize) ?? 0
            return partial + Int64(size)
        }
    }

    static func cacheKey(for voice: String) -> String {
        let normalized = voice.precomposedStringWithCanonicalMapping
        guard let data = normalized.data(using: .utf8) else {
            return voice.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? voice
        }
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
