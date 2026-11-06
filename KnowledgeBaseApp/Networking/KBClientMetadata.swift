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
    static let timezoneHeader = "X-KB-App-Timezone"
    static let localeHeader = "X-KB-App-Locale"
    static let structuredUIHeader = StructuredUIPreference.headerName

    let appVersion: String
    let buildNumber: String
    let platform: String
    let osVersion: String
    /// Matches `LogSession.shared.id` / on-disk log file naming.
    let logSessionId: String
    /// IANA timezone id from the device (e.g. `Europe/Moscow`).
    let timeZoneIdentifier: String
    /// App UI locale identifier (respects in-app language override).
    let localeIdentifier: String

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
        let resolvedVersion = version.flatMap { $0.isEmpty ? nil : $0 } ?? "0"
        let resolvedBuild = build.flatMap { $0.isEmpty ? nil : $0 } ?? "0"
        let localeId = AppLanguageStore.shared.resolvedLocale.identifier
        return KBClientMetadata(
            appVersion: resolvedVersion,
            buildNumber: resolvedBuild,
            platform: "ios",
            osVersion: os,
            logSessionId: LogSession.shared.id,
            timeZoneIdentifier: TimeZone.current.identifier,
            localeIdentifier: localeId.isEmpty ? "en" : localeId
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
        if !timeZoneIdentifier.isEmpty {
            request.setValue(timeZoneIdentifier, forHTTPHeaderField: Self.timezoneHeader)
        }
        if !localeIdentifier.isEmpty {
            request.setValue(localeIdentifier, forHTTPHeaderField: Self.localeHeader)
        }
        request.setValue(StructuredUIPreference.headerValue, forHTTPHeaderField: Self.structuredUIHeader)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    }
}
