import Foundation

/// Resolves `remote_ui` URL templates (`{{field}}`, `{{shared_url}}`, `{{shared_text}}`)
/// and turns relative paths into absolute URLs against the KB App API base.
enum RemoteUIURLBuilder {
    static func resolveTemplate(
        _ template: String?,
        formValues: [String: StructuredUIFormValue] = [:],
        sharedURL: String? = nil,
        sharedText: String? = nil
    ) -> String? {
        guard var result = template?.trimmingCharacters(in: .whitespacesAndNewlines),
              !result.isEmpty
        else { return nil }

        var replacements: [String: String] = [:]
        for (key, value) in formValues {
            replacements[key] = string(from: value)
        }
        if let sharedURL, !sharedURL.isEmpty {
            replacements["shared_url"] = sharedURL
        }
        if let sharedText, !sharedText.isEmpty {
            replacements["shared_text"] = sharedText
        }

        // {{key}} → percent-encoded value
        let pattern = /\{\{\s*([A-Za-z0-9_\.]+)\s*\}\}/
        while let match = result.firstMatch(of: pattern) {
            let key = String(match.1)
            let raw = replacements[key] ?? ""
            let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            result.replaceSubrange(match.range, with: encoded)
        }
        return result
    }

    static func absoluteURL(
        from resolved: String,
        apiBaseURL: URL?
    ) -> URL? {
        let trimmed = resolved.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        guard let apiBaseURL else { return nil }
        if trimmed.hasPrefix("/") {
            return URL(string: trimmed, relativeTo: apiBaseURL)?.absoluteURL
        }
        return apiBaseURL.appendingPathComponent(trimmed)
    }

    private static func string(from value: StructuredUIFormValue) -> String {
        switch value {
        case .bool(let flag):
            return flag ? "true" : "false"
        case .string(let text):
            return text
        case .strings(let list):
            return list.joined(separator: ",")
        case .number(let number):
            if number.rounded() == number {
                return String(Int(number))
            }
            return String(number)
        }
    }
}
