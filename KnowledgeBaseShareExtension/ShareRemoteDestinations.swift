import Foundation

/// Share-eligible `remote_ui` actions discovered from the Actions presets board (dynamic, no hardcode).
struct ShareRemoteDestination: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let urlTemplate: String
    let title: String?
}

enum ShareRemoteDestinations {
    /// Walk a Structured UI JSON tree for buttons with `action.type == remote_ui` and `share: true`.
    static func extract(fromBoardDetailJSON data: Data) -> [ShareRemoteDestination] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        let document = (root["document"] as? [String: Any]) ?? root
        let screen = document["screen"] as? [String: Any]
        var found: [ShareRemoteDestination] = []
        walk(node: screen, into: &found)
        return found
    }

    private static func walk(node: [String: Any]?, into found: inout [ShareRemoteDestination]) {
        guard let node else { return }
        if let action = node["action"] as? [String: Any],
           (action["type"] as? String) == "remote_ui",
           (action["share"] as? Bool) == true,
           let url = action["url"] as? String,
           !url.isEmpty
        {
            let id = (node["id"] as? String) ?? url
            let shareLabel = action["share_label"] as? String
            let buttonLabel = node["label"] as? String
            let title = action["title"] as? String
            let label = (shareLabel?.isEmpty == false ? shareLabel : nil)
                ?? (buttonLabel?.isEmpty == false ? buttonLabel : nil)
                ?? title
                ?? "Action"
            found.append(
                ShareRemoteDestination(
                    id: id,
                    label: label ?? "Action",
                    urlTemplate: url,
                    title: title
                )
            )
        }
        if let children = node["children"] as? [[String: Any]] {
            for child in children {
                walk(node: child, into: &found)
            }
        }
    }

    static func resolveURL(
        template: String,
        sharedURL: String?,
        sharedText: String?
    ) -> String {
        var result = template
        func replace(_ key: String, _ value: String) {
            let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            result = result.replacingOccurrences(of: "{{\(key)}}", with: encoded)
            result = result.replacingOccurrences(of: "{{ \(key) }}", with: encoded)
        }
        replace("shared_url", sharedURL ?? "")
        replace("shared_text", sharedText ?? "")
        replace("q", sharedText ?? "")
        return result
    }

    /// Flatten Structured UI JSON into readable text for the Share Extension result screen.
    static func plainText(fromDocumentJSON data: Data) -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8) ?? ""
        }
        let document = (root["document"] as? [String: Any]) ?? root
        let screen = document["screen"] as? [String: Any]
        var parts: [String] = []
        collectText(node: screen, into: &parts)
        return parts.joined(separator: "\n\n")
    }

    private static func collectText(node: [String: Any]?, into parts: inout [String]) {
        guard let node else { return }
        let type = node["type"] as? String
        if type == "markdown" || type == "text" || type == "callout",
           let text = node["text"] as? String,
           !text.isEmpty
        {
            parts.append(text)
        }
        if let children = node["children"] as? [[String: Any]] {
            for child in children {
                collectText(node: child, into: &parts)
            }
        }
    }
}
