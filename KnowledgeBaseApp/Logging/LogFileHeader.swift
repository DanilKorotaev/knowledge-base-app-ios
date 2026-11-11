import Darwin
import Foundation
import UIKit

enum LogFileHeader {
    struct Context: Equatable {
        var version: String
        var build: String
        var os: String
        var model: String
        var locale: String
        var timeZone: String
        var logSession: String
        var authenticated: Bool
    }

    static func text(_ context: Context) -> String {
        """
        app started
        version: \(context.version)
        build: \(context.build)
        os: \(context.os)
        model: \(context.model)
        locale: \(context.locale)
        timezone: \(context.timeZone)
        log_session: \(context.logSession)
        authenticated: \(context.authenticated ? "yes" : "no")
        """
    }

    static func current(sessionId: String) -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return text(
            Context(
                version: version,
                build: build,
                os: UIDevice.current.systemVersion,
                model: machineIdentifier(),
                locale: Locale.current.identifier,
                timeZone: TimeZone.current.identifier,
                logSession: sessionId,
                authenticated: KeychainTokenStore.token() != nil
            )
        )
    }

    static func machineIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}
