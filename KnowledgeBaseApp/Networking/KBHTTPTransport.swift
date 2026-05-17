import Alamofire
import Foundation
import QuartzCore

/// Single Alamofire entry point: auth headers, request/response logging.
final class KBHTTPTransport: @unchecked Sendable {
    private let session: Session
    private let urlSession: URLSession
    private let apiLogger = KBApiLogger(logger: makeLogger(tags: [.network, .http]))
    private let lock = NSLock()
    private var authToken: String?
    private var useE2EIntegrationUser: Bool

    init(authToken: String?, useE2EIntegrationUser: Bool = false, urlSession: URLSession = .shared) {
        self.authToken = authToken
        self.useE2EIntegrationUser = useE2EIntegrationUser
        self.urlSession = urlSession
        let configuration = urlSession.configuration
        self.session = Session(configuration: configuration)
    }

    func updateAuth(token: String?) {
        lock.lock()
        authToken = token
        lock.unlock()
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let id = UUID().uuidString
        let start = CACurrentMediaTime()
        let interceptor = makeInterceptor(requestId: id)
        let emptyCodes = Set(200 ..< 600)
        let response = await session.request(request, interceptor: interceptor)
            .serializingData(emptyResponseCodes: emptyCodes)
            .response
        switch response.result {
        case let .success(data):
            guard let http = response.response else {
                throw KnowledgeBaseAPIError.invalidResponse(statusCode: -1, apiMessage: nil)
            }
            apiLogger.log(response: http, data: data, id: id, startTime: start)
            return (data, http)
        case let .failure(error):
            if let http = response.response {
                apiLogger.log(response: http, data: response.data, id: id, startTime: start)
                return (response.data ?? Data(), http)
            }
            apiLogger.log(error: error, id: id, response: nil)
            throw error
        }
    }

    /// Streaming (SSE): URLSession bytes + same auth/logging as Alamofire requests.
    func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        let id = UUID().uuidString
        let start = CACurrentMediaTime()
        var adapted = request
        applyAuthHeaders(to: &adapted)
        apiLogger.log(request: adapted, id: id)
        do {
            let (bytes, response) = try await urlSession.bytes(for: adapted)
            guard let http = response as? HTTPURLResponse else {
                throw KnowledgeBaseAPIError.invalidResponse(statusCode: -1, apiMessage: nil)
            }
            apiLogger.log(response: http, data: nil, id: id, startTime: start)
            return (bytes, http)
        } catch {
            apiLogger.log(error: error, id: id, response: nil)
            throw error
        }
    }

    private func makeInterceptor(requestId: String) -> KBRequestInterceptor {
        lock.lock()
        let token = authToken
        let e2e = useE2EIntegrationUser
        lock.unlock()
        return KBRequestInterceptor(
            requestId: requestId,
            authToken: token,
            useE2EIntegrationUser: e2e,
            apiLogger: apiLogger
        )
    }

    private func applyAuthHeaders(to request: inout URLRequest) {
        lock.lock()
        let token = authToken
        let e2e = useE2EIntegrationUser
        lock.unlock()
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if e2e {
            request.setValue("1", forHTTPHeaderField: "X-KB-App-E2E")
        }
    }
}
