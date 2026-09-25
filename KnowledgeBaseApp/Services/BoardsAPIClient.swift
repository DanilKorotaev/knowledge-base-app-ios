import Foundation

struct BoardPeriodQuery: Equatable, Sendable {
    var period: String?
    var dateFrom: String?
    var dateTo: String?

    static let all = BoardPeriodQuery(period: nil, dateFrom: nil, dateTo: nil)

    var hasFilter: Bool {
        if let period, !period.isEmpty, period != "all" { return true }
        if let dateFrom, !dateFrom.isEmpty { return true }
        if let dateTo, !dateTo.isEmpty { return true }
        return false
    }
}

protocol BoardsAPIClientProtocol: Sendable {
    func fetchBoards() async throws -> [KBBoard]
    func fetchBoard(id: String, query: BoardPeriodQuery) async throws -> KBBoardDetail
    func refreshBoard(id: String, query: BoardPeriodQuery) async throws -> KBBoardDetail
}

extension BoardsAPIClientProtocol {
    func fetchBoard(id: String, period: String? = nil) async throws -> KBBoardDetail {
        try await fetchBoard(id: id, query: BoardPeriodQuery(period: period, dateFrom: nil, dateTo: nil))
    }

    func refreshBoard(id: String, period: String? = nil) async throws -> KBBoardDetail {
        try await refreshBoard(id: id, query: BoardPeriodQuery(period: period, dateFrom: nil, dateTo: nil))
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

    func fetchBoard(id: String, query: BoardPeriodQuery) async throws -> KBBoardDetail {
        _ = query
        guard let detail = DemoBoardsCatalog.detail(id: id) else {
            throw BoardsAPIError.notFound
        }
        return detail
    }

    func refreshBoard(id: String, query: BoardPeriodQuery) async throws -> KBBoardDetail {
        try await fetchBoard(id: id, query: query)
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

    func fetchBoard(id: String, query: BoardPeriodQuery) async throws -> KBBoardDetail {
        let url = boardURL(id: id, query: query, refresh: false)
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

    func refreshBoard(id: String, query: BoardPeriodQuery) async throws -> KBBoardDetail {
        let url = boardURL(id: id, query: query, refresh: true)
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
                return try await fetchBoard(id: id, query: query)
            }
            throw error
        }
    }

    private func boardURL(id: String, query: BoardPeriodQuery, refresh: Bool) -> URL {
        var url = baseURL.appendingPathComponent("api/boards/\(id)")
        if refresh {
            url = url.appendingPathComponent("refresh")
        }
        guard query.hasFilter else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = []
        if let period = query.period, !period.isEmpty, period != "all" {
            items.append(URLQueryItem(name: "period", value: period))
        }
        if let dateFrom = query.dateFrom, !dateFrom.isEmpty {
            items.append(URLQueryItem(name: "from", value: dateFrom))
        }
        if let dateTo = query.dateTo, !dateTo.isEmpty {
            items.append(URLQueryItem(name: "to", value: dateTo))
        }
        components?.queryItems = items.isEmpty ? nil : items
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
