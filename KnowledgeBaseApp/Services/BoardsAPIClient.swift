import Foundation

protocol BoardsAPIClientProtocol: Sendable {
    func fetchBoards() async throws -> [KBBoard]
    func fetchBoard(id: String, period: String?) async throws -> KBBoardDetail
    func refreshBoard(id: String, period: String?) async throws -> KBBoardDetail
}

extension BoardsAPIClientProtocol {
    func fetchBoard(id: String) async throws -> KBBoardDetail {
        try await fetchBoard(id: id, period: nil)
    }

    func refreshBoard(id: String) async throws -> KBBoardDetail {
        try await refreshBoard(id: id, period: nil)
    }
}

enum BoardsAPIError: Error, Equatable {
    case missingBaseURL
    case notFound
    case invalidResponse(statusCode: Int, apiMessage: String? = nil)
    case decodingFailed
}

/// Demo boards when no API base URL is configured.
struct StubBoardsAPIClient: BoardsAPIClientProtocol {
    func fetchBoards() async throws -> [KBBoard] {
        DemoBoardsCatalog.boards().sorted { $0.sortOrder < $1.sortOrder }
    }

    func fetchBoard(id: String, period: String?) async throws -> KBBoardDetail {
        _ = period
        guard let detail = DemoBoardsCatalog.detail(id: id) else {
            throw BoardsAPIError.notFound
        }
        return detail
    }

    func refreshBoard(id: String, period: String?) async throws -> KBBoardDetail {
        try await fetchBoard(id: id, period: period)
    }
}

/// Remote boards client. On **404** for the list endpoint, falls back to `DemoBoardsCatalog`
/// so the Overview tab works before the backend ships.
final class URLSessionBoardsAPIClient: BoardsAPIClientProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let transport: KBHTTPTransport
    private let useDemoFallback: Bool

    init(
        baseURL: URL,
        authToken: String?,
        urlSession: URLSession = .shared,
        useDemoFallback: Bool = true
    ) {
        self.baseURL = baseURL
        self.transport = KBHTTPTransport(authToken: authToken, urlSession: urlSession)
        self.useDemoFallback = useDemoFallback
    }

    convenience init?() {
        guard let base = AppConfiguration.url(for: AppConfiguration.Keys.apiBaseURL) else { return nil }
        let token = AppConfiguration.string(for: AppConfiguration.Keys.authToken)
        self.init(baseURL: base, authToken: token)
    }

    func fetchBoards() async throws -> [KBBoard] {
        let url = baseURL.appendingPathComponent("api/boards")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        do {
            let data = try await performData(request)
            guard let decoded = try? JSONDecoder().decode(KBBoardsListResponse.self, from: data) else {
                throw BoardsAPIError.decodingFailed
            }
            return decoded.boards
                .filter(\.enabled)
                .sorted { $0.sortOrder < $1.sortOrder }
        } catch let error as BoardsAPIError {
            if case .invalidResponse(let code, _) = error, code == 404, useDemoFallback {
                return DemoBoardsCatalog.boards().sorted { $0.sortOrder < $1.sortOrder }
            }
            throw error
        }
    }

    func fetchBoard(id: String, period: String?) async throws -> KBBoardDetail {
        let url = boardURL(id: id, period: period, refresh: false)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        do {
            let data = try await performData(request)
            guard let decoded = try? JSONDecoder().decode(KBBoardDetail.self, from: data) else {
                throw BoardsAPIError.decodingFailed
            }
            return decoded
        } catch let error as BoardsAPIError {
            if case .invalidResponse(let code, _) = error, code == 404 {
                if useDemoFallback, let demo = DemoBoardsCatalog.detail(id: id) {
                    return demo
                }
                throw BoardsAPIError.notFound
            }
            throw error
        }
    }

    func refreshBoard(id: String, period: String?) async throws -> KBBoardDetail {
        let url = boardURL(id: id, period: period, refresh: true)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        do {
            let data = try await performData(request)
            guard let decoded = try? JSONDecoder().decode(KBBoardDetail.self, from: data) else {
                throw BoardsAPIError.decodingFailed
            }
            return decoded
        } catch let error as BoardsAPIError {
            if case .invalidResponse(let code, _) = error, code == 404 {
                return try await fetchBoard(id: id, period: period)
            }
            throw error
        }
    }

    private func boardURL(id: String, period: String?, refresh: Bool) -> URL {
        var url = baseURL.appendingPathComponent("api/boards/\(id)")
        if refresh {
            url = url.appendingPathComponent("refresh")
        }
        guard let period, !period.isEmpty, period != "all" else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "period", value: period)]
        return components?.url ?? url
    }

    private func performData(_ request: URLRequest) async throws -> Data {
        let (data, http) = try await transport.data(for: request)
        guard (200 ... 299).contains(http.statusCode) else {
            throw BoardsAPIError.invalidResponse(
                statusCode: http.statusCode,
                apiMessage: KBAppAPIErrorMessage.parse(from: data)
            )
        }
        return data
    }
}
