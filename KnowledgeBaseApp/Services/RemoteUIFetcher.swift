import Foundation

enum RemoteUIFetcherError: Error, Equatable {
    case invalidURL
    case httpStatus(Int)
    case decodingFailed
    case emptyDocument
}

/// Fetches a Structured UI document from a remote_ui URL (absolute or API-relative).
struct RemoteUIFetcher: Sendable {
    var apiBaseURL: URL?
    var authToken: String?
    var urlSession: URLSession = .shared

    func fetchDocument(from urlString: String) async throws -> KBStructuredUIDocument {
        guard let url = RemoteUIURLBuilder.absoluteURL(from: urlString, apiBaseURL: apiBaseURL) else {
            throw RemoteUIFetcherError.invalidURL
        }
        var request = URLRequest(url: url)
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
