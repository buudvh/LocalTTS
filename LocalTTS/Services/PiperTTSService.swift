import Foundation

protocol PiperEngine {
    func synthesize(text: String, modelONNX: URL, modelConfig: URL, speed: Double, disablePunctuationPauses: Bool) async throws -> Data
}

final class PiperTTSService {
    private let modelStore: ModelStore
    private let engine: PiperEngine

    private(set) var currentModel: String?

    var engineStatus: String {
        "Piper ONNX C++ & eSpeak-NG local engine is active."
    }

    init(modelStore: ModelStore, engine: PiperEngine = ONNXPiperEngine()) {
        self.modelStore = modelStore
        self.engine = engine
    }

    func synthesize(text: String, voice: String, speed: Double, disablePunctuationPauses: Bool = false, enableTransliteration: Bool = true) async throws -> Data {
        let voiceId = voice.toASCIIID
        let modelONNX = modelStore.modelURL(for: voiceId, extension: "onnx")
        let modelConfig = modelStore.modelURL(for: voiceId, extension: "onnx.json")

        guard FileManager.default.fileExists(atPath: modelONNX.path),
              FileManager.default.fileExists(atPath: modelConfig.path) else {
            throw APIError.modelNotCached("Model '\(voice)' is not cached. Call /v1/models/prefetch first.")
        }

        currentModel = voice
        
        let preprocessedText = TextPreprocessor.shared.preprocess(text, enableTransliteration: enableTransliteration)
        
        return try await engine.synthesize(
            text: preprocessedText,
            modelONNX: modelONNX,
            modelConfig: modelConfig,
            speed: speed,
            disablePunctuationPauses: disablePunctuationPauses
        )
    }
}

struct UnavailablePiperEngine: PiperEngine {
    func synthesize(text: String, modelONNX: URL, modelConfig: URL, speed: Double, disablePunctuationPauses: Bool) async throws -> Data {
        throw APIError.engineUnavailable(
            "Native Piper synthesis is not linked yet. Add ONNX Runtime Mobile plus an eSpeak phonemizer binding, then implement PiperEngine."
        )
    }
}
