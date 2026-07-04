import Foundation

/// User-facing copy for voice transcription / upload failures.
enum VoicePipelineErrorMessage {
    /// Short factual reason shown under a fixed title like «Голосовое не распознано».
    static func forTranscription(_ error: Error) -> String {
        if let api = error as? KnowledgeBaseAPIError {
            switch api {
            case .invalidResponse(let statusCode, let apiMessage):
                if statusCode == 502 || statusCode == 504 {
                    return "Таймаут сервера (\(statusCode))."
                }
                if statusCode == 422 {
                    return "Речь в записи не распознана."
                }
                if let apiMessage, !apiMessage.isEmpty {
                    return apiMessage
                }
                if statusCode > 0 {
                    return "Ошибка сервера (\(statusCode))."
                }
            case .missingBaseURL:
                return "API не настроен."
            case .decodingFailed:
                return "Неверный ответ сервера."
            }
        }

        if let urlError = error as? URLError {
            return forNetwork(urlError)
        }

        let text = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return text
        }

        return "Неизвестная ошибка."
    }

    static func forSend(_ error: Error) -> String {
        if let urlError = error as? URLError {
            return "Не удалось отправить: \(forNetwork(urlError))"
        }
        return "Не удалось отправить сообщение."
    }

    private static func forNetwork(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            return "Нет подключения к интернету."
        case .networkConnectionLost:
            return "Соединение потеряно."
        case .timedOut:
            return "Таймаут."
        case .cannotFindHost, .cannotConnectToHost:
            return "Сервер недоступен."
        case .dataNotAllowed:
            return "Сеть недоступна для приложения."
        default:
            let text = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? "Ошибка сети." : text
        }
    }
}
