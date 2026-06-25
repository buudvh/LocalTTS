import Foundation


final class ModelStore: ObservableObject {
    private let fileManager: FileManager
    let rootURL: URL
    let modelsURL: URL
    private let voicesCacheURL: URL
    @Published var localVoiceIDs: [String] = []
    @Published var hasDictionary = false

    @MainActor
    func reloadLocalVoices() {
        localVoiceIDs = getLocalVoiceIDs()
    }

    @MainActor
    func reloadDictionaryStatus() {
        hasDictionary =
            FileManager.default.fileExists(
                atPath: rootURL.appendingPathComponent("non-vietnamese-words.plist").path
            )
            &&
            FileManager.default.fileExists(
                atPath: rootURL.appendingPathComponent("acronyms.plist").path
            )
    }

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

    func modelURL(for voiceId: String, extension ext: String) -> URL {
        modelsURL.appendingPathComponent(voiceId).appendingPathExtension(ext)
    }

    func modelExists(for voiceId: String) -> Bool {
        fileManager.fileExists(atPath: modelURL(for: voiceId, extension: "onnx").path)
            && fileManager.fileExists(atPath: modelURL(for: voiceId, extension: "onnx.json").path)
    }

    func bytesForVoice(_ voiceId: String) -> Int64 {
        ["onnx", "onnx.json"].reduce(Int64(0)) { partial, ext in
            let url = modelURL(for: voiceId, extension: ext)
            let size = ((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize) ?? 0
            return partial + Int64(size)
        }
    }

    func getLocalVoiceIDs() -> [String] {
        let files = (try? fileManager.contentsOfDirectory(
            at: modelsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        
        let onnxFiles = files.filter { $0.pathExtension == "onnx" }
        var voiceIds: [String] = []
        for file in onnxFiles {
            let voiceId = file.deletingPathExtension().lastPathComponent
            if modelExists(for: voiceId) {
                voiceIds.append(voiceId)
            }
        }
        return voiceIds
    }

    func deleteModel(for voiceId: String) throws {
        let onnxURL = modelURL(for: voiceId, extension: "onnx")
        let jsonURL = modelURL(for: voiceId, extension: "onnx.json")
        if fileManager.fileExists(atPath: onnxURL.path) {
            try fileManager.removeItem(at: onnxURL)
        }
        if fileManager.fileExists(atPath: jsonURL.path) {
            try fileManager.removeItem(at: jsonURL)
        }
    }
}

