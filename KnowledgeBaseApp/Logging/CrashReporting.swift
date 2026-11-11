import FirebaseCore
import FirebaseCrashlytics
import Foundation

enum CrashReporting {
    private(set) static var isConfigured = false

    static func start() {
        guard !isConfigured else { return }
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let values = NSDictionary(contentsOfFile: path),
              let appID = values["GOOGLE_APP_ID"] as? String,
              !appID.isEmpty else {
            return
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        isConfigured = true
        Crashlytics.crashlytics().setCustomValue(LogSession.shared.id, forKey: "log_session")
    }

    static func log(_ message: String) {
        guard isConfigured else { return }
        Crashlytics.crashlytics().log(message)
    }

    static func didCrashDuringPreviousExecution() -> Bool {
        guard isConfigured else { return false }
        return Crashlytics.crashlytics().didCrashDuringPreviousExecution()
    }

    static func testCrash(note: String = "") {
        guard isConfigured else { return }
        applyTestNote(note)
        Crashlytics.crashlytics().log("Test crash requested")
        fatalError("Test Crashlytics crash")
    }

    static func recordTestNonFatal(note: String) {
        guard isConfigured else { return }
        applyTestNote(note)
        let trimmed = sanitizedNote(note)
        let description = trimmed.isEmpty ? "Test non-fatal" : trimmed
        let error = NSError(
            domain: "com.coredan.KnowledgeBaseApp.crashlytics",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
        Crashlytics.crashlytics().record(error: error)
        Crashlytics.crashlytics().setCustomValue("", forKey: "test_note")
    }

    private static func applyTestNote(_ note: String) {
        Crashlytics.crashlytics().setCustomValue(sanitizedNote(note), forKey: "test_note")
    }

    private static func sanitizedNote(_ note: String) -> String {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let safe = CrashBreadcrumbPolicy.sanitized(trimmed), !safe.isEmpty else { return "" }
        return String(safe.prefix(200))
    }
}
