import Foundation
import Network

final class LocalHTTPServer: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastRequest: String?

    private let port: UInt16
    private let handler: APIHandler
    private let queue = DispatchQueue(label: "localtts.http.server")
    private var listener: NWListener?
    
    private var activeConnections: [UUID: NWConnection] = [:]
    private var restartAttempts = 0
    private let maxRestartAttempts = 3

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
        self.restartAttempts = 0
        
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            self.queue.async {
                switch state {
                case .ready:
                    self.restartAttempts = 0
                    Task { @MainActor in
                        self.isRunning = true
                    }
                case .failed(let error):
                    appLog("⚠️ LocalHTTPServer listener failed: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.isRunning = false
                        self.listener = nil
                    }
                    self.attemptRestart()
                case .cancelled:
                    appLog("⚠️ LocalHTTPServer listener cancelled.")
                    Task { @MainActor in
                        self.isRunning = false
                        self.listener = nil
                    }
                default:
                    break
                }
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        queue.async {
            self.listener?.cancel()
            self.listener = nil
            
            // Hủy toàn bộ kết nối active hiện tại để giải phóng cổng 17771 ngay lập tức
            for (id, connection) in self.activeConnections {
                appLog("🔌 Server stopping: force closing connection \(id)")
                connection.cancel()
            }
            self.activeConnections.removeAll()
            
            Task { @MainActor in
                self.isRunning = false
            }
        }
    }

    private func attemptRestart() {
        guard restartAttempts < maxRestartAttempts else {
            appLog("❌ Max server restart attempts reached (\(maxRestartAttempts)). Stopping auto-restart.")
            return
        }
        restartAttempts += 1
        let delay = Double(restartAttempts) * 2.0
        appLog("🔄 Auto-restarting server (\(restartAttempts)/\(maxRestartAttempts)) in \(delay) seconds...")
        
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                do {
                    try self.start()
                    appLog("✅ Server auto-restarted successfully.")
                } catch {
                    appLog("⚠️ Failed to auto-restart server: \(error.localizedDescription)")
                }
            }
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        
        let connectionID = UUID()
        activeConnections[connectionID] = connection
        
        // Thiết lập timeout 15 giây cho kết nối này để tránh rò rỉ socket mồ côi
        let timeoutWorkItem = DispatchWorkItem { [weak self, weak connection] in
            guard let self else { return }
            self.queue.async {
                guard self.activeConnections[connectionID] != nil else { return }
                appLog("⚠️ HTTP connection \(connectionID) timed out. Force closing.")
                self.closeConnection(connectionID)
            }
        }
        
        queue.asyncAfter(deadline: .now() + 15.0, execute: timeoutWorkItem)
        
        receive(into: Data(), connection: connection, connectionID: connectionID, timeoutWorkItem: timeoutWorkItem)
    }

    private func closeConnection(_ id: UUID) {
        if let connection = activeConnections.removeValue(forKey: id) {
            connection.cancel()
        }
    }

    private func receive(into buffer: Data, connection: NWConnection, connectionID: UUID, timeoutWorkItem: DispatchWorkItem) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, isComplete, error in
            guard let self else {
                timeoutWorkItem.cancel()
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
                    
                    self.queue.async {
                        connection.send(content: response.serialize(), completion: .contentProcessed { [weak self] _ in
                            guard let self else { return }
                            self.queue.async {
                                timeoutWorkItem.cancel()
                                self.closeConnection(connectionID)
                            }
                        })
                    }
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
                
                self.queue.async {
                    connection.send(content: response.serialize(), completion: .contentProcessed { [weak self] _ in
                        guard let self else { return }
                        self.queue.async {
                            timeoutWorkItem.cancel()
                            self.closeConnection(connectionID)
                        }
                    })
                }
                return
            }

            self.receive(into: nextBuffer, connection: connection, connectionID: connectionID, timeoutWorkItem: timeoutWorkItem)
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
