import Foundation

/// How long a temporary default voice session stays active before auto-reset.
enum DefaultVoiceSessionTTL: String, CaseIterable, Identifiable, Sendable {
    case thirtyMinutes
    case oneHour
    case twoHours
    case endOfDay
    case indefinite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .thirtyMinutes: return L10n.string("voice.ttl.thirty_minutes")
        case .oneHour: return L10n.string("voice.ttl.one_hour")
        case .twoHours: return L10n.string("voice.ttl.two_hours")
        case .endOfDay: return L10n.string("voice.ttl.end_of_day")
        case .indefinite: return L10n.string("voice.ttl.indefinite")
        }
    }

    func expirationDate(from start: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .thirtyMinutes:
            return start.addingTimeInterval(30 * 60)
        case .oneHour:
            return start.addingTimeInterval(60 * 60)
        case .twoHours:
            return start.addingTimeInterval(2 * 60 * 60)
        case .endOfDay:
            let startOfDay = calendar.startOfDay(for: start)
            return calendar.date(byAdding: .day, value: 1, to: startOfDay)
        case .indefinite:
            return nil
        }
    }
}

struct DefaultVoiceSessionPreference: Codable, Equatable, Sendable {
    let sessionId: String
    let sessionTitle: String
    let expiresAt: Date?
    let previousSessionId: String?
    let previousSessionTitle: String?

    func isValid(at date: Date = Date()) -> Bool {
        guard let expiresAt else { return true }
        return date < expiresAt
    }

    func remainingInterval(at date: Date = Date()) -> TimeInterval? {
        guard let expiresAt else { return nil }
        return max(0, expiresAt.timeIntervalSince(date))
    }
}
