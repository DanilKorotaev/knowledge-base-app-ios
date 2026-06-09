import Foundation

protocol DefaultVoiceSessionStoreProtocol: Sendable {
    func load() -> DefaultVoiceSessionPreference?
    func save(_ preference: DefaultVoiceSessionPreference)
    func clear()
}

final class DefaultVoiceSessionStore: DefaultVoiceSessionStoreProtocol {
    static let shared = DefaultVoiceSessionStore()

    private let userDefaults: UserDefaultsServiceDescription

    init(userDefaults: UserDefaultsServiceDescription = UserDefaultsService.shared) {
        self.userDefaults = userDefaults
    }

    func load() -> DefaultVoiceSessionPreference? {
        guard let data = userDefaults.object(forKey: .defaultVoiceSession) as? Data else { return nil }
        return try? JSONDecoder().decode(DefaultVoiceSessionPreference.self, from: data)
    }

    func save(_ preference: DefaultVoiceSessionPreference) {
        guard let data = try? JSONEncoder().encode(preference) else { return }
        userDefaults.set(data, forKey: .defaultVoiceSession)
    }

    func clear() {
        userDefaults.removeObject(forKey: .defaultVoiceSession)
    }
}
