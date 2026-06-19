import Foundation

final class AppLogger {
    static let shared = AppLogger()
    
    private let logURL: URL
    private let lock = NSLock()
    
    private init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        logURL = paths[0].appendingPathComponent("app.log")
        // Initialize file
        if !FileManager.default.fileExists(atPath: logURL.path) {
            try? "".write(to: logURL, atomically: true, encoding: .utf8)
        }
    }
    
    func log(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logLine = "[\(timestamp)] \(message)\n"
        
        print(logLine, terminator: "") // Print to console
        
        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logURL, options: .atomic)
            }
        }
    }
    
    func getLogs() -> String {
        lock.lock()
        defer { lock.unlock() }
        return (try? String(contentsOf: logURL, encoding: .utf8)) ?? "No logs found."
    }
    
    func clearLogs() {
        lock.lock()
        defer { lock.unlock() }
        try? "".write(to: logURL, atomically: true, encoding: .utf8)
    }
}

func appLog(_ message: String) {
    AppLogger.shared.log(message)
}
