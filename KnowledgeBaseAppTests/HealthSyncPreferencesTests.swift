import Foundation
import Testing
@testable import KnowledgeBaseApp

@Suite("HealthSyncPreferences")
struct HealthSyncPreferencesTests {
    @Test("persists enabled flag in UserDefaults")
    func persistsEnabledFlag() {
        let defaults = UserDefaults.standard
        let previous = defaults.bool(forKey: "kb.health.sync_enabled")
        defer { defaults.set(previous, forKey: "kb.health.sync_enabled") }

        HealthSyncPreferences.isSyncEnabled = true
        #expect(defaults.bool(forKey: "kb.health.sync_enabled"))

        HealthSyncPreferences.isSyncEnabled = false
        #expect(!defaults.bool(forKey: "kb.health.sync_enabled"))
    }
}
