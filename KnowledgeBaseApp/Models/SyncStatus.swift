import Foundation

/// Stale-while-revalidate sync state for sessions list or a chat thread.
enum SyncStatus: Equatable {
    case idle
    case refreshing
    case upToDate(lastSyncedAt: Date)
    case offline(lastSyncedAt: Date?)
    case failed(message: String, lastSyncedAt: Date?)

    var showsBanner: Bool {
        switch self {
        case .idle: false
        case .refreshing, .upToDate, .offline, .failed: true
        }
    }

    var isProminent: Bool {
        switch self {
        case .refreshing, .offline, .failed: true
        case .idle, .upToDate: false
        }
    }

    var lastSyncedAt: Date? {
        switch self {
        case .idle, .refreshing: nil
        case .upToDate(let date): date
        case .offline(let date): date
        case .failed(_, let date): date
        }
    }

    var displayText: String {
        switch self {
        case .idle:
            return ""
        case .refreshing:
            return "Обновление…"
        case .upToDate(let date):
            return "Обновлено \(SyncStatusFormatting.relativeAge(since: date))"
        case .offline(let date):
            if let date {
                return "Офлайн · данные от \(SyncStatusFormatting.relativeAge(since: date))"
            }
            return "Офлайн"
        case .failed(let message, let date):
            let base = message.isEmpty ? "Не удалось обновить" : message
            guard let date else { return base }
            return "\(base) · данные от \(SyncStatusFormatting.relativeAge(since: date))"
        }
    }
}

enum SyncStatusFormatting {
    static func relativeAge(since date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "только что" }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes) мин назад"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours) ч назад"
        }
        let days = hours / 24
        return "\(days) дн назад"
    }
}

enum SyncNetworkError {
    static func isOffline(_ error: Error) -> Bool {
        let ns = error as NSError
        guard ns.domain == NSURLErrorDomain else { return false }
        return [
            URLError.notConnectedToInternet.rawValue,
            URLError.networkConnectionLost.rawValue,
            URLError.dataNotAllowed.rawValue,
            URLError.internationalRoamingOff.rawValue,
        ].contains(ns.code)
    }

    static func failureStatus(
        error: Error,
        lastSyncedAt: Date?,
        isPathOnline: Bool
    ) -> SyncStatus {
        if !isPathOnline || isOffline(error) {
            return .offline(lastSyncedAt: lastSyncedAt)
        }
        return .failed(message: error.localizedDescription, lastSyncedAt: lastSyncedAt)
    }
}
