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
            return L10n.string("sync.updating")
        case .upToDate(let date):
            return L10n.format("sync.updated_format", SyncStatusFormatting.relativeAge(since: date))
        case .offline(let date):
            if let date {
                return L10n.format("sync.offline_data_format", SyncStatusFormatting.relativeAge(since: date))
            }
            return L10n.string("sync.offline")
        case .failed(let message, let date):
            let base = message.isEmpty ? L10n.string("sync.failed_default") : message
            guard let date else { return base }
            return L10n.format(
                "sync.failed_data_format",
                base,
                SyncStatusFormatting.relativeAge(since: date)
            )
        }
    }
}

enum SyncStatusFormatting {
    static func relativeAge(since date: Date, locale: Locale = AppLanguageStore.shared.resolvedLocale) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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
