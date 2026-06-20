import Foundation
import Network

final class LocalHTTPServer: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastRequest: String?

    private let port: UInt16
    private let handler: APIHandler
    private let queue = DispatchQueue(label: "localtts.http.server")
    private var listener: NWListener?

    init(port: UInt16, handler: APIHandler) {
        self.port = port
        self.handler = handler
    }

    func start() throws {
        guard listener == nil else { return }
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw APIError.internalError("Invalid port \(port).")
        }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        if let loopback = IPv4Address("127.0.0.1") {
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(loopback), port: endpointPort)
        }

        let listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.isRunning = true
                case .failed, .cancelled:
                    self?.isRunning = false
                    self?.listener = nil
                default:
                    break
                }
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(into: Data(), connection: connection)
    }

    private func receive(into buffer: Data, connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            var nextBuffer = buffer
            if let data {
                nextBuffer.append(data)
            }

            if let request = Self.parseRequest(nextBuffer) {
                Task {
                    let bgSession = BackgroundTaskSession.begin(name: "LocalTTS-Request")
                    defer { bgSession.end() }
                    
                    await MainActor.run {
                        self.lastRequest = "\(request.method) \(request.path)"
                    }
                    let response = await self.handler.handle(request)
                    connection.send(content: response.serialize(), completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                }
                return
            }

            if isComplete || error != nil || nextBuffer.count > 2_000_000 {
                let response = HTTPResponse(
                    statusCode: 400,
                    reason: "Bad Request",
                    headers: ["Content-Type": "application/json; charset=utf-8"],
                    body: Data(#"{"error":"bad_request","message":"Malformed HTTP request."}"#.utf8)
                )
                connection.send(content: response.serialize(), completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }

            self.receive(into: nextBuffer, connection: connection)
        }
    }

    private static func parseRequest(_ data: Data) -> HTTPRequest? {
        guard let headerRange = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = data[..<headerRange.lowerBound]
        let bodyStart = headerRange.upperBound
        let headerText = String(decoding: headerData, as: UTF8.self)
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        let parts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<separator]).lowercased()
            let value = String(line[line.index(after: separator)...]).trimmed
            headers[key] = value
        }

        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        let availableBodyBytes = data.distance(from: bodyStart, to: data.endIndex)
        guard availableBodyBytes >= contentLength else { return nil }

        let bodyEnd = data.index(bodyStart, offsetBy: contentLength)
        let body = Data(data[bodyStart..<bodyEnd])
        let path = parts[1].split(separator: "?", maxSplits: 1).first.map(String.init) ?? parts[1]

        return HTTPRequest(
            method: parts[0].uppercased(),
            path: path,
            headers: headers,
            body: body
        )
    }
}
