import Foundation

enum RemoteUIFetcherError: Error, Equatable {
    case invalidURL
    case httpStatus(Int)
    case decodingFailed
    case emptyDocument
}

/// Fetches a Structured UI document for `remote_ui`.
/// Absolute URLs to other hosts go through ``GET /api/remote-ui?url=…`` (host allowlist on API).
/// Same-origin / relative API paths are requested directly.
struct RemoteUIFetcher: Sendable {
    var apiBaseURL: URL?
    var authToken: String?
    var urlSession: URLSession = .shared

    func fetchDocument(from urlString: String) async throws -> KBStructuredUIDocument {
        guard let target = RemoteUIURLBuilder.absoluteURL(from: urlString, apiBaseURL: apiBaseURL) else {
            throw RemoteUIFetcherError.invalidURL
        }
        let requestURL = try proxyURLIfNeeded(for: target)
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let authToken, !authToken.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await urlSession.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200 ... 299).contains(status) else {
            throw RemoteUIFetcherError.httpStatus(status)
        }
        return try Self.decodeDocument(from: data)
    }

    /// When the target is not on the KB API host, wrap as ``/api/remote-ui?url=``.
    private func proxyURLIfNeeded(for target: URL) throws -> URL {
        guard let apiBaseURL else { return target }
        let apiHost = apiBaseURL.host?.lowercased()
        let targetHost = target.host?.lowercased()
        let sameHost = apiHost != nil && apiHost == targetHost
        let isApiPath = target.path.hasPrefix("/api/")
        if sameHost || (targetHost == nil && isApiPath) {
            return target
        }
        // Relative /api/... already absolute against apiBase — handled above.
        // External absolute URL → proxy.
        var components = URLComponents(
            url: apiBaseURL.appendingPathComponent("api/remote-ui"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "url", value: target.absoluteString)]
        guard let proxied = components?.url else {
            throw RemoteUIFetcherError.invalidURL
        }
        return proxied
    }

    static func decodeDocument(from data: Data) throws -> KBStructuredUIDocument {
        let decoder = JSONDecoder()
        if let document = try? decoder.decode(KBStructuredUIDocument.self, from: data) {
            return document
        }
        struct Envelope: Decodable {
            let document: KBStructuredUIDocument?
            let schemaVersion: Int?
            let screen: KBStructuredUINode?

            enum CodingKeys: String, CodingKey {
                case document
                case schemaVersion = "schema_version"
                case screen
            }
        }
        if let env = try? decoder.decode(Envelope.self, from: data) {
            if let document = env.document {
                return document
            }
            if let screen = env.screen {
                return KBStructuredUIDocument(schemaVersion: env.schemaVersion ?? 1, screen: screen)
            }
        }
        throw RemoteUIFetcherError.decodingFailed
    }
}
