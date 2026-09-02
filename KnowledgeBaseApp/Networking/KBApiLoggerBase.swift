import Foundation

class KBApiLoggerBase {
    let logger: Logger
    let settings: LoggerSettingsProviderDescription
    let successStatusCodes = 200 ..< 300

    var isVerboseLog: Bool { settings.isVerboseLog }

    init(logger: Logger, settings: LoggerSettingsProviderDescription = KBLoggerSettings.shared) {
        self.logger = logger
        self.settings = settings
    }

    func logMessage(from headers: [String: String]?) -> String {
        guard let headers, !headers.isEmpty else { return "" }
        let headersText = headers.map { " \($0.key) : \($0.value)" }.joined(separator: "\n")
        return "Headers: [\n\(headersText)\n]"
    }

    func logMessage(from response: URLResponse, data: Data?) -> String {
        var result: [String] = []
        if let url = response.url?.absoluteString {
            result.append(url)
        }
        if let httpResponse = response as? HTTPURLResponse {
            let localised = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode).capitalized
            result.append("Status: \(httpResponse.statusCode) - \(localised)")
            let headerFields = httpResponse.allHeaderFields.reduce(into: [String: String]()) { acc, pair in
                if let key = pair.key as? String, let value = pair.value as? String {
                    acc[key] = value
                }
            }
            result.append(logMessage(from: headerFields))
        }
        if let data {
            result.append(logMessage(from: data))
        }
        return result.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    func logMessage(from body: Data) -> String {
        let maxBodyBytes = 4_096
        if body.count > maxBodyBytes {
            return "HTTP Body: [\(body.count) bytes — truncated for logs]"
        }
        let bodyText: String
        if let object = try? JSONSerialization.jsonObject(with: body, options: .allowFragments),
           JSONSerialization.isValidJSONObject(object),
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
           let prettyString = String(data: pretty, encoding: .utf8) {
            bodyText = Self.redactLargeJSONFields(prettyString)
        } else {
            bodyText = String(data: body, encoding: .utf8) ?? "N/A"
        }
        return "HTTP Body: [\n\(bodyText)\n]"
    }

    /// Avoid dumping base64 health payloads into verbose logs.
    private static func redactLargeJSONFields(_ text: String) -> String {
        guard text.count > 8_192 else { return text }
        return String(text.prefix(8_192)) + "\n… [truncated \(text.count - 8_192) chars]"
    }

    func shortUrl(_ url: URL?) -> String {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return ""
        }
        let queryItems = components.queryItems?.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
        return [components.path, queryItems].compactMap { $0 }.joined(separator: "?")
    }
}
