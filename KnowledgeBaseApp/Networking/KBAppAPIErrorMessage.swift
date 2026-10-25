import Foundation

/// Parses the KB App API error envelope from `docs/KB_APP_API_CONTRACT.md`.
enum KBAppAPIErrorMessage {
    static func parse(from data: Data) -> String? {
        struct Envelope: Decodable {
            struct Err: Decodable {
                let code: String?
                let message: String?
                let detail: String?
            }

            let error: Err?
        }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data), let e = envelope.error {
            let parts = [e.message, e.detail, e.code].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if let first = parts.first {
                return first
            }
        }

        let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw, !raw.isEmpty else { return nil }
        return raw
    }
}

extension KnowledgeBaseAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return String(localized: "auth.error_missing_api_url")
        case let .invalidResponse(statusCode, apiMessage):
            return KBAppAPIErrorMessage.userFacing(
                statusCode: statusCode,
                apiMessage: apiMessage,
                fallback: String(localized: "network.request_failed")
            )
        case .decodingFailed:
            return String(localized: "network.decoding_failed")
        }
    }
}

extension FilesAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .invalidResponse(statusCode, apiMessage):
            return KBAppAPIErrorMessage.userFacing(
                statusCode: statusCode,
                apiMessage: apiMessage,
                fallback: String(localized: "network.request_failed")
            )
        case .decodingFailed:
            return String(localized: "network.decoding_failed")
        }
    }
}

extension BoardsAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return String(localized: "auth.error_missing_api_url")
        case .notFound:
            return String(localized: "boards.error.not_found")
        case .decodingFailed:
            return String(localized: "network.decoding_failed")
        case let .invalidResponse(statusCode, apiMessage):
            return KBAppAPIErrorMessage.userFacing(
                statusCode: statusCode,
                apiMessage: apiMessage,
                fallback: String(localized: "boards.error.generic")
            )
        }
    }
}

extension KBAppAPIErrorMessage {
    /// Prefer a human message; never surface raw "Access token истёк" / enum dumps.
    static func userFacing(
        statusCode: Int,
        apiMessage: String?,
        fallback: String
    ) -> String {
        if statusCode == 401 || statusCode == 403 {
            return String(localized: "auth.session_expired")
        }
        if let apiMessage, !apiMessage.isEmpty, !isTechnicalAuthMessage(apiMessage) {
            return apiMessage
        }
        if statusCode < 0 {
            return String(localized: "network.invalid_response")
        }
        if statusCode > 0 {
            return "\(fallback) (HTTP \(statusCode))"
        }
        return fallback
    }

    private static func isTechnicalAuthMessage(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("access token")
            || lower.contains("refresh")
            || lower.contains("истёк")
            || lower.contains("истек")
            || lower.contains("unauthorized")
            || lower.contains("bearer")
    }
}
