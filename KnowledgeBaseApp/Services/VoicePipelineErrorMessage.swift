import Foundation

/// User-facing copy for voice transcription / upload failures.
enum VoicePipelineErrorMessage {
    /// Short factual reason shown under a fixed title like «Voice not recognized».
    static func forTranscription(_ error: Error) -> String {
        if let api = error as? KnowledgeBaseAPIError {
            switch api {
            case .invalidResponse(let statusCode, let apiMessage):
                if statusCode == 502 || statusCode == 504 {
                    return L10n.format("error.server_timeout_format", statusCode)
                }
                if statusCode == 422 {
                    return L10n.string("error.speech_not_recognized")
                }
                if let apiMessage, !apiMessage.isEmpty {
                    return apiMessage
                }
                if statusCode > 0 {
                    return L10n.format("error.server_format", statusCode)
                }
            case .missingBaseURL:
                return L10n.string("error.api_not_configured")
            case .decodingFailed:
                return L10n.string("error.invalid_server_response")
            }
        }

        if let urlError = error as? URLError {
            return forNetwork(urlError)
        }

        let text = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return text
        }

        return L10n.string("error.unknown")
    }

    static func forSend(_ error: Error) -> String {
        if let urlError = error as? URLError {
            return L10n.format("error.send_failed_format", forNetwork(urlError))
        }
        return L10n.string("error.send_failed")
    }

    private static func forNetwork(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            return L10n.string("error.no_internet")
        case .networkConnectionLost:
            return L10n.string("error.connection_lost")
        case .timedOut:
            return L10n.string("error.timeout")
        case .cannotFindHost, .cannotConnectToHost:
            return L10n.string("error.server_unavailable")
        case .dataNotAllowed:
            return L10n.string("error.network_not_allowed")
        default:
            let text = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? L10n.string("error.network_generic") : text
        }
    }
}
