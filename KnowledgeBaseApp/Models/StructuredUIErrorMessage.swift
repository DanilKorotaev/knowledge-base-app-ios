import Foundation

/// User-facing errors for Structured UI media (no raw API JSON in alerts).
enum StructuredUIErrorMessage {
    static func userFacing(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            return sanitize(description)
        }
        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else {
            return L10n.string("structured_ui.media_load_failed")
        }
        return sanitize(description)
    }

    private static func sanitize(_ text: String) -> String {
        if text.hasPrefix("{"),
           let data = text.data(using: .utf8) {
            struct DetailOnly: Decodable { let detail: String? }
            if let detail = try? JSONDecoder().decode(DetailOnly.self, from: data).detail?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !detail.isEmpty {
                if detail == "Not Found" {
                    return L10n.string("structured_ui.media_load_failed")
                }
                return detail
            }
            if let parsed = KBAppAPIErrorMessage.parse(from: data) {
                return parsed
            }
            return L10n.string("structured_ui.media_load_failed")
        }
        return text
    }
}
