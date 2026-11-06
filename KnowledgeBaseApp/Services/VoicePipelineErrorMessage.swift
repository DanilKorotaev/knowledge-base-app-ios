import Foundation

#if canImport(Alamofire)
import Alamofire
#endif

/// User-facing copy for voice transcription / upload failures.
enum VoicePipelineErrorMessage {
    /// Short factual reason shown under a fixed title like «Voice not recognized».
    static func forTranscription(_ error: Error) -> String {
        let unwrapped = unwrap(error)

        if let api = unwrapped as? KnowledgeBaseAPIError {
            switch api {
            case .invalidResponse(let statusCode, _):
                if statusCode == 502 || statusCode == 504 {
                    return L10n.string("error.transcription_timeout")
                }
                if statusCode == 422 {
                    return L10n.string("error.speech_not_recognized")
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

        if let urlError = unwrapped as? URLError {
            return forNetwork(urlError)
        }

        // Never surface Alamofire / system dumps on the composer plank.
        return L10n.string("error.transcription_failed")
    }

    static func forSend(_ error: Error) -> String {
        let unwrapped = unwrap(error)
        if let urlError = unwrapped as? URLError {
            return L10n.format("error.send_failed_format", forNetwork(urlError))
        }
        return L10n.string("error.send_failed")
    }

    /// Timeouts / gateway blips worth silent auto-retry with the same client id.
    static func isTransientTranscriptionFailure(_ error: Error) -> Bool {
        let unwrapped = unwrap(error)
        if let urlError = unwrapped as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .cannotConnectToHost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }
        if let api = unwrapped as? KnowledgeBaseAPIError,
           case .invalidResponse(let statusCode, _) = api {
            return statusCode == 502 || statusCode == 504 || statusCode == 408
        }
        return false
    }

    private static func forNetwork(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            return L10n.string("error.no_internet")
        case .networkConnectionLost:
            return L10n.string("error.connection_lost")
        case .timedOut:
            return L10n.string("error.transcription_timeout")
        case .cannotFindHost, .cannotConnectToHost:
            return L10n.string("error.server_unavailable")
        case .dataNotAllowed:
            return L10n.string("error.network_not_allowed")
        default:
            return L10n.string("error.network_generic")
        }
    }

    private static func unwrap(_ error: Error) -> Error {
        #if canImport(Alamofire)
        if let af = error as? AFError {
            if let url = af.underlyingError as? URLError {
                return url
            }
            if let underlying = af.underlyingError {
                return unwrap(underlying)
            }
        }
        #endif
        let ns = error as NSError
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
            return unwrap(underlying)
        }
        return error
    }
}
