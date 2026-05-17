import Alamofire
import Foundation

final class KBRequestInterceptor: RequestInterceptor, @unchecked Sendable {
    private let requestId: String
    private let authToken: String?
    private let useE2EIntegrationUser: Bool
    private let apiLogger: KBApiLogger

    init(requestId: String, authToken: String?, useE2EIntegrationUser: Bool, apiLogger: KBApiLogger) {
        self.requestId = requestId
        self.authToken = authToken
        self.useE2EIntegrationUser = useE2EIntegrationUser
        self.apiLogger = apiLogger
    }

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest
        if let authToken, !authToken.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        if useE2EIntegrationUser {
            request.setValue("1", forHTTPHeaderField: "X-KB-App-E2E")
        }
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
}
