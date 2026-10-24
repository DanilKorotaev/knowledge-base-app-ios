import Foundation

protocol AuthAPIClientProtocol: Sendable {
    func signupStatus() async throws -> AuthSignupStatus
    func login(login: String, password: String) async throws -> AuthTokenResponse
    func register(login: String, password: String, email: String?) async throws -> AuthTokenResponse
    func refresh(refreshToken: String) async throws -> AuthTokenResponse
    func me(accessToken: String) async throws -> AuthUserDTO
    func changePassword(accessToken: String, currentPassword: String?, newPassword: String) async throws
    func logout(accessToken: String?, refreshToken: String?) async throws
}

enum AuthAPIError: LocalizedError, Equatable {
    case missingBaseURL
    case invalidResponse(statusCode: Int, message: String?)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "Server URL is not configured"
        case let .invalidResponse(_, message):
            return message ?? "Authentication failed"
        case .decodingFailed:
            return "Unexpected server response"
        }
    }
}

struct URLSessionAuthAPIClient: AuthAPIClientProtocol {
    private let baseURL: URL
    private let urlSession: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.decoder = JSONDecoder()
    }

    static func makeFromConfiguration() -> URLSessionAuthAPIClient? {
        guard let base = AppConfiguration.url(for: AppConfiguration.Keys.apiBaseURL) else { return nil }
        return URLSessionAuthAPIClient(baseURL: base)
    }

    func signupStatus() async throws -> AuthSignupStatus {
        try await get(path: "api/auth/signup-status", authorized: false)
    }

    func login(login: String, password: String) async throws -> AuthTokenResponse {
        try await post(
            path: "api/auth/login",
            body: ["login": login, "password": password],
            authorized: false
        )
    }

    func register(login: String, password: String, email: String?) async throws -> AuthTokenResponse {
        var body: [String: Any] = ["login": login, "password": password]
        if let email, !email.isEmpty {
            body["email"] = email
        }
        return try await post(path: "api/auth/register", body: body, authorized: false)
    }

    func refresh(refreshToken: String) async throws -> AuthTokenResponse {
        try await post(
            path: "api/auth/refresh",
            body: ["refresh_token": refreshToken],
            authorized: false
        )
    }

    func me(accessToken: String) async throws -> AuthUserDTO {
        let envelope: AuthMeResponse = try await get(
            path: "api/auth/me",
            authorized: true,
            accessToken: accessToken
        )
        return envelope.user
    }

    func changePassword(accessToken: String, currentPassword: String?, newPassword: String) async throws {
        var body: [String: Any] = ["new_password": newPassword]
        if let currentPassword {
            body["current_password"] = currentPassword
        }
        let _: [String: String] = try await post(
            path: "api/auth/change-password",
            body: body,
            authorized: true,
            accessToken: accessToken
        )
    }

    func logout(accessToken: String?, refreshToken: String?) async throws {
        var body: [String: Any] = [:]
        if let refreshToken, !refreshToken.isEmpty {
            body["refresh_token"] = refreshToken
        }
        let _: [String: String] = try await post(
            path: "api/auth/logout",
            body: body,
            authorized: accessToken != nil,
            accessToken: accessToken
        )
    }

    // MARK: - HTTP

    private func get<T: Decodable>(
        path: String,
        authorized: Bool,
        accessToken: String? = nil
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if authorized, let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return try await perform(request)
    }

    private func post<T: Decodable>(
        path: String,
        body: [String: Any],
        authorized: Bool,
        accessToken: String? = nil
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authorized, let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthAPIError.invalidResponse(statusCode: -1, message: nil)
        }
        if !(200 ..< 300).contains(http.statusCode) {
            let message = Self.apiMessage(from: data)
            throw AuthAPIError.invalidResponse(statusCode: http.statusCode, message: message)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AuthAPIError.decodingFailed
        }
    }

    private static func apiMessage(from data: Data) -> String? {
        guard
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if let detail = obj["detail"] as? String { return detail }
        if let message = obj["message"] as? String { return message }
        if let error = obj["error"] as? String { return error }
        return nil
    }
}
