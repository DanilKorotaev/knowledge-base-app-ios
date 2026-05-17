import Foundation

struct LoggerTag: Equatable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(for type: Any.Type) {
        rawValue = String(describing: type)
    }
}

extension LoggerTag {
    static let common = LoggerTag(rawValue: "Common")
    static let network = LoggerTag(rawValue: "Network")
    static let http = LoggerTag(rawValue: "HTTP")
    static let sessions = LoggerTag(rawValue: "Sessions")
    static let chat = LoggerTag(rawValue: "Chat")
    static let files = LoggerTag(rawValue: "Files")
    static let voice = LoggerTag(rawValue: "Voice")
    static let config = LoggerTag(rawValue: "Config")
    static let debug = LoggerTag(rawValue: "Debug")
    static let userDefaultsService = LoggerTag(rawValue: "UserDefaultsService")
}
