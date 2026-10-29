import Alamofire
import Foundation

final class KBRequestInterceptor: RequestInterceptor, @unchecked Sendable {
    private let requestId: String
    private let authToken: String?
    /// When set (post-refresh retry), always win over Keychain to avoid delete+add races.
    private let forceAuthToken: String?
    private let useE2EIntegrationUser: Bool
    private let clientMetadata: KBClientMetadata
    private let apiLogger: KBApiLogger

    init(
        requestId: String,
        authToken: String?,
        forceAuthToken: String? = nil,
        useE2EIntegrationUser: Bool,
        clientMetadata: KBClientMetadata = .current,
        apiLogger: KBApiLogger
    ) {
        self.requestId = requestId
        self.authToken = authToken
        self.forceAuthToken = forceAuthToken
        self.useE2EIntegrationUser = useE2EIntegrationUser
        self.clientMetadata = clientMetadata
        self.apiLogger = apiLogger
    }

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest
        if let token = resolvedBearer() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if useE2EIntegrationUser {
            request.setValue("1", forHTTPHeaderField: "X-KB-App-E2E")
        }
        clientMetadata.apply(to: &request)
        apiLogger.log(request: request, id: requestId)
        completion(.success(request))
    }

    func retry(
        _ request: Request,
        for session: Session,
        dueTo error: Error,
        completion: @escaping (RetryResult) -> Void
    ) {
        completion(.doNotRetry)
    }

    private func resolvedBearer() -> String? {
        if let forced = forceAuthToken?.trimmingCharacters(in: .whitespacesAndNewlines), !forced.isEmpty {
            return forced
        }
        if let live = KeychainTokenStore.token()?.trimmingCharacters(in: .whitespacesAndNewlines), !live.isEmpty {
            return live
        }
        if let authToken, !authToken.isEmpty {
            return authToken
        }
        return nil
    }
}
