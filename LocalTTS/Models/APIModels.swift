import Foundation

struct HealthResponse: Codable {
    let status: String
    let server: String
    let engine: String
    let currentModel: String?
    let cache: CacheSummary
}

struct CacheSummary: Codable {
    let voicesCached: Bool
    let modelCount: Int
    let totalBytes: Int64
}

struct VoicesResponse: Codable {
    let voices: [String]
    let source: String
    let cached: Bool
}

struct TTSSynthesisRequest: Codable {
    let text: String
    let voice: String?
    let speed: Double?
    let disablePunctuationPauses: Bool?
}

struct PrefetchRequest: Codable {
    let voices: [String]
}

struct PrefetchResponse: Codable {
    let results: [PrefetchResult]
}

struct PrefetchResult: Codable {
    let voice: String
    let onnxCached: Bool
    let configCached: Bool
    let bytes: Int64
    let message: String
}

struct APIErrorResponse: Codable {
    let error: String
    let message: String
}

struct Voice: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

extension String {
    var toASCIIID: String {
        let lowercased = self.lowercased()
        let folding = lowercased.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US"))
        var result = ""
        var lastWasUnderscore = false
        
        for char in folding {
            if char.isASCII && (char.isLetter || char.isNumber) {
                result.append(char)
                lastWasUnderscore = false
            } else if !lastWasUnderscore {
                result.append("_")
                lastWasUnderscore = true
            }
        }
        
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        if trimmed.isEmpty {
            var hash: UInt64 = 5381
            for byte in self.utf8 {
                hash = ((hash << 5) &+ hash) &+ UInt64(byte)
            }
            return "voice_" + String(hash)
        }
        return trimmed
    }
}

extension Voice {
    init(name: String) {
        self.name = name
        self.id = name.toASCIIID
    }
}
