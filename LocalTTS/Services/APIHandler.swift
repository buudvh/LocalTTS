import Foundation

final class APIHandler {
    private let nghiClient: NghiTTSClient
    private let ttsService: PiperTTSService
    private let modelStore: ModelStore
    private let maxTextLength = 5_000

    init(nghiClient: NghiTTSClient, ttsService: PiperTTSService, modelStore: ModelStore) {
        self.nghiClient = nghiClient
        self.ttsService = ttsService
        self.modelStore = modelStore
    }

    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        do {
            if request.method == "OPTIONS" {
                return HTTPResponse(
                    statusCode: 204,
                    reason: "No Content",
                    headers: ["Content-Length": "0"],
                    body: Data()
                )
            }

            switch (request.method, request.path) {
            case ("GET", "/health"):
                return try json(HealthResponse(
                    status: "ok",
                    server: "LocalTTS/1.0",
                    engine: ttsService.engineStatus,
                    currentModel: ttsService.currentModel,
                    cache: modelStore.cacheSummary()
                ))

            case ("GET", "/v1/voices"):
                let voices = try await nghiClient.fetchVietnameseVoices(forceRefresh: false)
                return try json(VoicesResponse(voices: voices.map { $0.name }, source: "nghitts.app", cached: true))

            case ("GET", "/logs"):
                let logText = AppLogger.shared.getLogs()
                return HTTPResponse(
                    statusCode: 200,
                    reason: "OK",
                    headers: [
                        "Content-Type": "text/plain; charset=utf-8",
                        "Content-Length": "\(logText.utf8.count)"
                    ],
                    body: Data(logText.utf8)
                )

            case ("POST", "/logs/clear"):
                AppLogger.shared.clearLogs()
                let responseText = "Logs cleared."
                return HTTPResponse(
                    statusCode: 200,
                    reason: "OK",
                    headers: [
                        "Content-Type": "text/plain; charset=utf-8",
                        "Content-Length": "\(responseText.utf8.count)"
                    ],
                    body: Data(responseText.utf8)
                )

            case ("POST", "/v1/models/prefetch"):
                let body = try decode(PrefetchRequest.self, from: request.body)
                guard !body.voices.isEmpty else {
                    throw APIError.badRequest("'voices' must contain at least one voice name.")
                }
                let results = try await nghiClient.prefetchModels(voices: body.voices)
                return try json(PrefetchResponse(results: results))

            case ("POST", "/v1/dictionary/update"):
                do {
                    try await nghiClient.downloadCSVFiles()
                    let responseText = "Dictionary files successfully updated."
                    return HTTPResponse(
                        statusCode: 200,
                        reason: "OK",
                        headers: [
                            "Content-Type": "text/plain; charset=utf-8",
                            "Content-Length": "\(responseText.utf8.count)"
                        ],
                        body: Data(responseText.utf8)
                    )
                } catch {
                    throw APIError.upstream("Failed to update dictionary files: \(error.localizedDescription)")
                }

            case ("POST", "/v1/tts"):
                let body = try decode(TTSSynthesisRequest.self, from: request.body)
                let text = body.text.trimmed
                guard !text.isEmpty else {
                    throw APIError.badRequest("'text' is required.")
                }
                guard text.count <= maxTextLength else {
                    throw APIError.badRequest("'text' must be \(maxTextLength) characters or fewer.")
                }

                let voiceName = (body.voice?.trimmed.isEmpty == false)
                    ? body.voice!.trimmed.precomposedStringWithCanonicalMapping
                    : NghiTTSClient.defaultVietnameseVoice.name

                let voices = try await nghiClient.fetchVietnameseVoices(forceRefresh: false)
                guard voices.contains(where: { $0.name == voiceName }) else {
                    throw APIError.badRequest("Unsupported NghiTTS voice: \(voiceName)")
                }

                let speed = body.speed ?? 1.0
                guard (0.5...2.0).contains(speed) else {
                    throw APIError.badRequest("'speed' must be between 0.5 and 2.0.")
                }

                let voiceId = voiceName.toASCIIID
                guard modelStore.modelExists(for: voiceId) else {
                    throw APIError.badRequest("Giọng đọc '\(voiceName)' chưa được tải về server. Vui lòng tải model trên ứng dụng trước khi sử dụng.")
                }

                let disablePunctuationPauses = body.disablePunctuationPauses ?? false
                let enableTransliteration = body.enableTransliteration ?? false

                let audio = try await ttsService.synthesize(
                    text: text,
                    voice: voiceName,
                    speed: speed,
                    disablePunctuationPauses: disablePunctuationPauses,
                    enableTransliteration: enableTransliteration
                )
                return HTTPResponse(
                    statusCode: 200,
                    reason: "OK",
                    headers: [
                        "Content-Type": "audio/wav",
                        "Content-Length": "\(audio.count)"
                    ],
                    body: audio
                )

            case (_, "/health"), (_, "/v1/voices"), (_, "/v1/models/prefetch"), (_, "/v1/tts"), (_, "/logs"), (_, "/logs/clear"), (_, "/v1/dictionary/update"):
                throw APIError.methodNotAllowed("Method \(request.method) is not allowed for \(request.path).")

            default:
                throw APIError.notFound("Route not found: \(request.path)")
            }
        } catch let error as APIError {
            return errorResponse(error)
        } catch {
            return errorResponse(.internalError(error.localizedDescription))
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.badRequest("Invalid JSON body: \(error.localizedDescription)")
        }
    }

    private func json<T: Encodable>(_ value: T, statusCode: Int = 200) throws -> HTTPResponse {
        let data = try JSONEncoder.pretty.encode(value)
        return HTTPResponse(
            statusCode: statusCode,
            reason: statusCode == 200 ? "OK" : "Error",
            headers: [
                "Content-Type": "application/json; charset=utf-8",
                "Content-Length": "\(data.count)"
            ],
            body: data
        )
    }

    private func errorResponse(_ error: APIError) -> HTTPResponse {
        let body = (try? JSONEncoder.pretty.encode(APIErrorResponse(
            error: error.code,
            message: error.localizedDescription
        ))) ?? Data()

        return HTTPResponse(
            statusCode: error.statusCode,
            reason: "Error",
            headers: [
                "Content-Type": "application/json; charset=utf-8",
                "Content-Length": "\(body.count)"
            ],
            body: body
        )
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
