import Foundation

enum APIError: LocalizedError {
    case badRequest(String)
    case notFound(String)
    case methodNotAllowed(String)
    case upstream(String)
    case modelNotCached(String)
    case engineUnavailable(String)
    case internalError(String)

    var errorDescription: String? {
        switch self {
        case .badRequest(let message),
             .notFound(let message),
             .methodNotAllowed(let message),
             .upstream(let message),
             .modelNotCached(let message),
             .engineUnavailable(let message),
             .internalError(let message):
            return message
        }
    }

    var statusCode: Int {
        switch self {
        case .badRequest: return 400
        case .notFound: return 404
        case .methodNotAllowed: return 405
        case .upstream: return 502
        case .modelNotCached: return 409
        case .engineUnavailable: return 501
        case .internalError: return 500
        }
    }

    var code: String {
        switch self {
        case .badRequest: return "bad_request"
        case .notFound: return "not_found"
        case .methodNotAllowed: return "method_not_allowed"
        case .upstream: return "upstream_error"
        case .modelNotCached: return "model_not_cached"
        case .engineUnavailable: return "engine_unavailable"
        case .internalError: return "internal_error"
        }
    }
}
