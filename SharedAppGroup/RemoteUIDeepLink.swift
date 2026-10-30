import Foundation

/// Deep link into the host app to present a `remote_ui` screen.
/// `knowledgebase://remote-ui?url=<absolute-or-template>&title=<optional>`
enum RemoteUIDeepLink {
    static let scheme = "knowledgebase"
    static let host = "remote-ui"

    static func makeURL(targetURL: String, title: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        var items = [URLQueryItem(name: "url", value: targetURL)]
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            items.append(URLQueryItem(name: "title", value: title))
        }
        components.queryItems = items
        return components.url
    }

    static func parse(_ url: URL) -> (url: String, title: String?)? {
        guard url.scheme?.lowercased() == scheme, url.host?.lowercased() == host else {
            return nil
        }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let target = items.first(where: { $0.name == "url" })?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !target.isEmpty
        else {
            return nil
        }
        let title = items.first { $0.name == "title" }?.value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (target, (title?.isEmpty == false) ? title : nil)
    }
}
