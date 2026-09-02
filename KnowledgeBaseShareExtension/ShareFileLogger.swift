import Foundation

/// Lightweight file logger for the Share Extension only (separate from the main app FileLogger).
enum ShareFileLogger {
    private static let lock = NSLock()
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static var logFileURL: URL? {
        ShareLogPaths.currentLogFileURL()
    }

    static func info(_ message: String, file: String = #fileID, function: String = #function) {
        write(level: "INFO", message: message, file: file, function: function)
    }

    static func error(_ message: String, file: String = #fileID, function: String = #function) {
        write(level: "ERROR", message: message, file: file, function: function)
    }

    private static func write(level: String, message: String, file: String, function: String) {
        guard let url = logFileURL else { return }
        let stamp = isoFormatter.string(from: Date())
        let line = "\(stamp) [\(level)] \(file) \(function) — \(message)\n"
        lock.lock()
        defer { lock.unlock() }
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    defer { try? handle.close() }
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                }
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
        #if DEBUG
        print("[KB Share] \(level): \(message)")
        #endif
    }
}
