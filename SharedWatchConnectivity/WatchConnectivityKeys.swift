import Foundation

/// Metadata keys shared between iOS companion and watchOS app.
enum WatchConnectivityKeys {
    static let messageType = "type"
    static let voiceQuery = "voice_query"
    static let watchLog = "watch_log"
    static let recordingID = "recording_id"
    static let logLine = "log_line"
    static let logTimestamp = "log_timestamp"

    static let defaultSessionID = "default_session_id"
    static let defaultSessionTitle = "default_session_title"
    static let expiresAt = "expires_at"

    static let lastResponsePreview = "last_response_preview"
    static let lastResponseError = "last_response_error"
    static let relayStatus = "relay_status"
}

enum WatchRelayStatus: String {
    case processing
    case success
    case error
}

struct WatchVoiceContext: Equatable, Sendable {
    var sessionID: String?
    var sessionTitle: String?
    var expiresAt: Date?
    var lastResponsePreview: String?
    var lastResponseError: String?
    var relayStatus: WatchRelayStatus?

    init(applicationContext: [String: Any]) {
        let rawID = applicationContext[WatchConnectivityKeys.defaultSessionID] as? String
        sessionID = rawID?.isEmpty == false ? rawID : nil

        let rawTitle = applicationContext[WatchConnectivityKeys.defaultSessionTitle] as? String
        sessionTitle = rawTitle?.isEmpty == false ? rawTitle : nil

        if let interval = applicationContext[WatchConnectivityKeys.expiresAt] as? TimeInterval {
            expiresAt = Date(timeIntervalSince1970: interval)
        } else {
            expiresAt = nil
        }

        if let rawPreview = applicationContext[WatchConnectivityKeys.lastResponsePreview] as? String {
            let cleaned = TerminalSanitizer.stripEscapeSequences(rawPreview)
            lastResponsePreview = cleaned.isEmpty ? nil : cleaned
        } else {
            lastResponsePreview = nil
        }
        if let rawError = applicationContext[WatchConnectivityKeys.lastResponseError] as? String {
            let cleaned = TerminalSanitizer.stripEscapeSequences(rawError)
            lastResponseError = cleaned.isEmpty ? nil : cleaned
        } else {
            lastResponseError = nil
        }

        if let raw = applicationContext[WatchConnectivityKeys.relayStatus] as? String {
            relayStatus = WatchRelayStatus(rawValue: raw)
        } else {
            relayStatus = nil
        }
    }

    var displaySessionTitle: String {
        sessionTitle ?? "No voice default"
    }

    var isDefaultExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt
    }
}
