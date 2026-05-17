import Foundation

extension URLRequest {
    /// cURL representation for verbose network logging.
    var kbCURL: String {
        let method = "-X \(httpMethod ?? "GET")"
        let urlPart = url.map { "--url '\($0.absoluteString)'" }
        let header = allHTTPHeaderFields?
            .map { "-H '\($0): \($1)'" }
            .joined(separator: " \\\n")
        let dataPart: String?
        if let httpBody, !httpBody.isEmpty {
            if let object = try? JSONSerialization.jsonObject(with: httpBody),
               let pretty = try? JSONSerialization.data(withJSONObject: object, options: .prettyPrinted),
               let prettyString = String(data: pretty, encoding: .utf8) {
                let escaped = prettyString.replacingOccurrences(of: "'", with: "'\\''")
                dataPart = "--data '\(escaped)'"
            } else if let bodyString = String(data: httpBody, encoding: .utf8) {
                let escaped = bodyString.replacingOccurrences(of: "'", with: "'\\''")
                dataPart = "--data '\(escaped)'"
            } else {
                dataPart = "--data '<\(httpBody.count) bytes binary>'"
            }
        } else {
            dataPart = nil
        }
        return (["curl", method, urlPart, header, dataPart].compactMap { $0 }).joined(separator: " \\\n")
    }
}
