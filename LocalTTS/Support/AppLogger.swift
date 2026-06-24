import Foundation

final class AppLogger {
    static let shared = AppLogger()
    
    private let logURL: URL
    private let lock = NSLock()
    private let dateFormatter = ISO8601DateFormatter()
    
    private init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cacheURL = paths.first else {
            fatalError("Could not locate caches directory.")
        }
        logURL = cacheURL.appendingPathComponent("app.log")
        
        let isLoggingEnabled = UserDefaults.standard.bool(forKey: PreprocessorSettingKey.debugLoggingEnabled)
        print("[AppLogger] Khởi tạo. Trạng thái debug log: \(isLoggingEnabled)")
    }
    
    func log(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        
        let timestamp = dateFormatter.string(from: Date())
        let logLine = "[\(timestamp)] \(message)\n"
        
        print(logLine, terminator: "") // Print to console
        
        if let data = logLine.data(using: .utf8) {
            if !FileManager.default.fileExists(atPath: logURL.path) {
                try? "".write(to: logURL, atomically: true, encoding: .utf8)
            }
            
            if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                defer { try? fileHandle.close() }
                do {
                    try fileHandle.seekToEnd()
                    try fileHandle.write(contentsOf: data)
                } catch {
                    print("Failed to write to log file: \(error)")
                }
            }
        }
    }
    
    func getLogs() -> String {
        lock.lock()
        defer { lock.unlock() }
        
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: logURL.path),
              let fileSize = attributes[.size] as? UInt64 else {
            return "No logs found."
        }
        
        let maxBytes: UInt64 = 1_024_000 // ~1MB
        let startOffset = fileSize > maxBytes ? fileSize - maxBytes : 0
        
        do {
            let fileHandle = try FileHandle(forReadingFrom: logURL)
            defer { try? fileHandle.close() }
            try fileHandle.seek(toOffset: startOffset)
            if let data = try fileHandle.readToEnd() {
                var logs = String(decoding: data, as: UTF8.self)
                if startOffset > 0 {
                    logs = "[... Truncated due to size ...]\n" + logs
                }
                return logs
            }
        } catch {
            return "Failed to read logs: \(error.localizedDescription)"
        }
        return "No logs found."
    }
    
    func clearLogs() {
        lock.lock()
        defer { lock.unlock() }
        try? "".write(to: logURL, atomically: true, encoding: .utf8)
    }
}

func appLog(_ message: @autoclosure () -> String) {
    guard UserDefaults.standard.bool(forKey: PreprocessorSettingKey.debugLoggingEnabled) else { return }
    AppLogger.shared.log(message())
}

