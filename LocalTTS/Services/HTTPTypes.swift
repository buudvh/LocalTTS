import Foundation

struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
}

struct HTTPResponse {
    let statusCode: Int
    let reason: String
    let headers: [String: String]
    let body: Data

    func serialize() -> Data {
        var response = "HTTP/1.1 \(statusCode) \(reason)\r\n"
        var mergedHeaders = headers
        mergedHeaders["Connection"] = "close"
        mergedHeaders["Access-Control-Allow-Origin"] = "*"
        mergedHeaders["Access-Control-Allow-Headers"] = "Content-Type"
        mergedHeaders["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"

        for (key, value) in mergedHeaders.sorted(by: { $0.key < $1.key }) {
            response += "\(key): \(value)\r\n"
        }
        response += "\r\n"

        var data = Data(response.utf8)
        data.append(body)
        return data
    }
}
