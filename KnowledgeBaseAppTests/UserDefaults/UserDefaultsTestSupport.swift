import Foundation
@testable import KnowledgeBaseApp

final class MockUserDefaultsServiceSettings: UserDefaultsServiceSettingsDescription {
    var isVerboseLoggingEnabled = false
    var ignoredAddOrUpdateKeys: [String] = []

    func shouldIgnoreAddOrUpdate(for key: String) -> Bool {
        ignoredAddOrUpdateKeys.contains(key)
    }
}

enum UserDefaultsTestSupport {
    static func makeIsolatedStorage() -> (suiteName: String, storage: UserDefaults) {
        let suiteName = "kb.tests.\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: suiteName)!
        return (suiteName, storage)
    }

    static func tearDown(storage: UserDefaults, suiteName: String) {
        storage.removePersistentDomain(forName: suiteName)
    }
}
