import Foundation

struct UserDefaultsKey: ExpressibleByStringLiteral, Hashable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        rawValue = value
    }
}

struct UserDefaultsKeyPrefix: Hashable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    func appending(_ suffix: String) -> String {
        rawValue + suffix
    }
}

extension UserDefaultsKey {
    // App configuration (Settings screen; token is in Keychain)
    static let apiBaseURL = UserDefaultsKey("kbapp.config.api_base_url")

    // Logger settings
    static let loggerDebugConsole = UserDefaultsKey("kb.logger.isDebugLogger")
    static let loggerFileEnabled = UserDefaultsKey("kb.logger.isFileLoggerEnabled")
    static let loggerVerboseNetwork = UserDefaultsKey("kb.logger.isVerboseLog")
    static let loggerMaxLogFiles = UserDefaultsKey("kb.logger.maxFilesToStorage")
    static let loggerSessionId = UserDefaultsKey("kb.logger.session.currentId")

    // Inspector settings
    static let inspectorVerboseLogging = UserDefaultsKey("kb.userdefaults.inspector.verboseLogging")
    static let inspectorIgnoredUpdateKeys = UserDefaultsKey("kb.userdefaults.inspector.ignoredUpdateKeys")
}

extension UserDefaultsKeyPrefix {
    static let loggerTag = UserDefaultsKeyPrefix("kb.logger.tag.")
}
