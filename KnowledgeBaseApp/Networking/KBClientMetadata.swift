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

    let appVersion: String
    let buildNumber: String
    let platform: String
    let osVersion: String

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
            osVersion: os
        )
    }

    func apply(to request: inout URLRequest) {
        request.setValue(appVersion, forHTTPHeaderField: Self.versionHeader)
        request.setValue(buildNumber, forHTTPHeaderField: Self.buildHeader)
        request.setValue(platform, forHTTPHeaderField: Self.platformHeader)
        request.setValue(osVersion, forHTTPHeaderField: Self.osHeader)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    }
}
