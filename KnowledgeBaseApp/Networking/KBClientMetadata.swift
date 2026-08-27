import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Marketing/build/OS identity attached to every KB App API request.
struct KBClientMetadata: Equatable, Sendable {
    static let versionHeader = "X-KB-App-Version"
    static let buildHeader = "X-KB-App-Build"
    static let platformHeader = "X-KB-App-Platform"
    static let osHeader = "X-KB-App-OS"
    static let logSessionHeader = "X-KB-App-Log-Session"
    static let structuredUIHeader = StructuredUIPreference.headerName

    let appVersion: String
    let buildNumber: String
    let platform: String
    let osVersion: String
    /// Matches `LogSession.shared.id` / on-disk log file naming.
    let logSessionId: String

    var userAgent: String {
        "KnowledgeBaseApp/\(appVersion) (\(platform) \(osVersion); build \(buildNumber))"
    }

    /// Human-readable label for Settings / support: `1.0.0 (90)`.
    var versionBuildLabel: String {
        "\(appVersion) (\(buildNumber))"
    }

    static var current: KBClientMetadata {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let build = (info?["CFBundleVersion"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #if canImport(UIKit)
        let os = UIDevice.current.systemVersion
        #else
        let os = "unknown"
        #endif
        return KBClientMetadata(
            appVersion: (version?.isEmpty == false) ? version! : "0",
            buildNumber: (build?.isEmpty == false) ? build! : "0",
            platform: "ios",
            osVersion: os,
            logSessionId: LogSession.shared.id
        )
    }

    func apply(to request: inout URLRequest) {
        request.setValue(appVersion, forHTTPHeaderField: Self.versionHeader)
        request.setValue(buildNumber, forHTTPHeaderField: Self.buildHeader)
        request.setValue(platform, forHTTPHeaderField: Self.platformHeader)
        request.setValue(osVersion, forHTTPHeaderField: Self.osHeader)
        if !logSessionId.isEmpty {
            request.setValue(logSessionId, forHTTPHeaderField: Self.logSessionHeader)
        }
        request.setValue(StructuredUIPreference.headerValue, forHTTPHeaderField: Self.structuredUIHeader)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    }
}
