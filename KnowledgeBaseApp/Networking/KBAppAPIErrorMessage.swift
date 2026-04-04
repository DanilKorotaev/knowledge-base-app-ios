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
            return "API base URL is not configured."
        case let .invalidResponse(statusCode, apiMessage):
            if let apiMessage, !apiMessage.isEmpty {
                return apiMessage
            }
            if statusCode < 0 {
                return "Invalid server response."
            }
            return "Request failed (HTTP \(statusCode))."
        case .decodingFailed:
            return "Could not read server response."
        }
    }
}

extension FilesAPIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .invalidResponse(statusCode, apiMessage):
            if let apiMessage, !apiMessage.isEmpty {
                return apiMessage
            }
            if statusCode < 0 {
                return "Invalid server response."
            }
            return "Request failed (HTTP \(statusCode))."
        case .decodingFailed:
            return "Could not read server response."
        }
    }
}
