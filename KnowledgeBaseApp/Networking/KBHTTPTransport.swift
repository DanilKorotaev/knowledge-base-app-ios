import Alamofire
import Foundation
import QuartzCore

/// Single Alamofire entry point: auth headers, request/response logging.
final class KBHTTPTransport: @unchecked Sendable {
    /// Long-running SSE (Cursor agent can take minutes before first byte).
    private static let streamingRequestTimeout: TimeInterval = 600

    private let session: Session
    private let streamingSession: URLSession
    private let apiLogger = KBApiLogger(logger: makeLogger(tags: [.network, .http]))
    private let clientMetadata: KBClientMetadata
    private let lock = NSLock()
    private var authToken: String?
    private var useE2EIntegrationUser: Bool

    init(
        authToken: String?,
        useE2EIntegrationUser: Bool = false,
        clientMetadata: KBClientMetadata = .current,
        urlSession: URLSession = .shared
    ) {
        self.authToken = authToken
        self.useE2EIntegrationUser = useE2EIntegrationUser
        self.clientMetadata = clientMetadata
        let configuration = urlSession.configuration.copy() as! URLSessionConfiguration
        configuration.timeoutIntervalForRequest = Self.streamingRequestTimeout
        configuration.timeoutIntervalForResource = 3_600
        self.streamingSession = URLSession(configuration: configuration)
        self.session = Session(configuration: urlSession.configuration)
    }

    func updateAuth(token: String?) {
        lock.lock()
        authToken = token
        lock.unlock()
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let first = try await performData(request)
        if first.1.statusCode != 401 {
            return first
        }
        // Skip refresh for auth endpoints themselves.
        if Self.isAuthPath(request.url) {
            return first
        }
        guard KeychainTokenStore.refreshToken() != nil else {
            // Access expired and we have nothing to renew — send user to login.
            await AuthSessionStore.shared.invalidateLocalSession(
                reason: "401 without refresh token"
            )
            return first
        }
        do {
            let newToken = try await AuthSessionStore.shared.refreshAccessToken()
            updateAuth(token: newToken)
            // Force the just-issued access token on retry. Preferring Keychain alone can
            // race with delete+add writes and re-send the expired Bearer → false logout.
            let retry = try await performData(request, forceAuthToken: newToken)
            if retry.1.statusCode == 401 {
                await AuthSessionStore.shared.invalidateLocalSession(
                    reason: "401 after refresh"
                )
            }
            return retry
        } catch {
            // Network / 5xx during refresh must not wipe a still-valid refresh session.
            if AuthAPIError.isDefinitiveAuthFailure(error) {
                await AuthSessionStore.shared.invalidateLocalSession(
                    reason: "refresh failed: \(error.localizedDescription)"
                )
            } else {
                apiLogger.logger.releaseInfo(
                    "Auth refresh deferred (keeping session): \(error.localizedDescription)"
                )
            }
            return first
        }
    }

    private func performData(
        _ request: URLRequest,
        forceAuthToken: String? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let id = UUID().uuidString
        let start = CACurrentMediaTime()
        let interceptor = makeInterceptor(requestId: id, forceAuthToken: forceAuthToken)
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

    private static func isAuthPath(_ url: URL?) -> Bool {
        guard let path = url?.path else { return false }
        return path.contains("/api/auth/")
    }

    /// Streaming (SSE): URLSession bytes + same auth/logging as Alamofire requests.
    func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, HTTPURLResponse) {
        let id = UUID().uuidString
        let start = CACurrentMediaTime()
        var adapted = request
        applyCommonHeaders(to: &adapted)
        apiLogger.log(request: adapted, id: id)
        do {
            let (bytes, response) = try await streamingSession.bytes(for: adapted)
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

    private func makeInterceptor(
        requestId: String,
        forceAuthToken: String? = nil
    ) -> KBRequestInterceptor {
        lock.lock()
        let e2e = useE2EIntegrationUser
        lock.unlock()
        return KBRequestInterceptor(
            requestId: requestId,
            authToken: forceAuthToken?.nilIfEmpty ?? resolvedAuthToken(),
            forceAuthToken: forceAuthToken,
            useE2EIntegrationUser: e2e,
            clientMetadata: clientMetadata,
            apiLogger: apiLogger
        )
    }

    private func applyCommonHeaders(to request: inout URLRequest) {
        lock.lock()
        let e2e = useE2EIntegrationUser
        lock.unlock()
        if let token = resolvedAuthToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if e2e {
            request.setValue("1", forHTTPHeaderField: "X-KB-App-E2E")
        }
        clientMetadata.apply(to: &request)
    }

    /// Prefer live Keychain/session token so account switch does not keep a stale Bearer.
    private func resolvedAuthToken() -> String? {
        if let live = KeychainTokenStore.token()?.trimmingCharacters(in: .whitespacesAndNewlines),
           !live.isEmpty {
            return live
        }
        lock.lock()
        defer { lock.unlock() }
        return authToken
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

