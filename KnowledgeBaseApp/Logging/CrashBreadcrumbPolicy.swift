import Foundation

enum CrashBreadcrumbPolicy {
    static let infoTags: Set<LoggerTag> = [.network, .http, .push, .health, .watch, .voice]
    static let maxCharacters = 500

    static func shouldMirror(
        tags: [LoggerTag],
        level: LogLevel,
        buildLevel: LogBuildLevel,
        loggingEnabled: Bool = true
    ) -> Bool {
        guard loggingEnabled, buildLevel == .release else { return false }
        switch level {
        case .error, .nonFatal, .critical:
            return true
        case .info:
            return tags.contains(where: infoTags.contains)
        case .warning:
            return false
        }
    }

    static func sanitized(_ text: String) -> String? {
        let lowered = text.lowercased()
        if lowered.contains("authorization") || lowered.contains("bearer ") {
            return nil
        }
        if text.count <= maxCharacters {
            return text
        }
        return String(text.prefix(maxCharacters))
    }
}
