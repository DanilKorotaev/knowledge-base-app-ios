import Foundation

/// User-facing copy for voice transcription / upload failures.
enum VoicePipelineErrorMessage {
    static func forTranscription(_ error: Error) -> String {
        if let api = error as? KnowledgeBaseAPIError {
            switch api {
            case .invalidResponse(let statusCode, let apiMessage):
                if statusCode == 502 || statusCode == 504 {
                    return "Не удалось распознать речь: сервер не ответил вовремя. Проверьте сеть и VPN, затем нажмите «Повторить»."
                }
                if statusCode == 422 {
                    return "Не удалось распознать речь в записи. Попробуйте записать ещё раз или повторите позже."
                }
                if let apiMessage, !apiMessage.isEmpty {
                    return apiMessage
                }
            case .missingBaseURL:
                return "API не настроен. Проверьте подключение к серверу."
            case .decodingFailed:
                return "Не удалось обработать ответ сервера при распознавании речи."
            }
        }

        if let urlError = error as? URLError {
            return forNetwork(urlError)
        }

        let text = error.localizedDescription.lowercased()
        if text.contains("timed out") || text.contains("timeout") {
            return "Таймаут при распознавании речи. Проверьте VPN и интернет, затем нажмите «Повторить»."
        }
        if text.contains("offline") || text.contains("internet") || text.contains("connection") {
            return "Нет соединения с сервером. Проверьте сеть и VPN, затем нажмите «Повторить»."
        }

        return "Не удалось распознать речь. Нажмите «Повторить» или удалите запись."
    }

    static func forSend(_ error: Error) -> String {
        if let urlError = error as? URLError {
            return "Не удалось отправить: \(forNetwork(urlError))"
        }
        return "Не удалось отправить сообщение. Запись сохранена — попробуйте ещё раз."
    }

    private static func forNetwork(_ error: Error) -> String {
        let code = (error as? URLError)?.code
        switch code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return "Нет подключения к интернету."
        case .timedOut:
            return "Превышено время ожидания ответа сервера."
        default:
            return "Проблема с сетью (\(error.localizedDescription))."
        }
    }
}
