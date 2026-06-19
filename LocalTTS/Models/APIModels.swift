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
