import Foundation

protocol AuthAPIClientProtocol: Sendable {
    func signupStatus() async throws -> AuthSignupStatus
    func login(login: String, password: String) async throws -> AuthTokenResponse
    func register(login: String, password: String, email: String?) async throws -> AuthTokenResponse
    func refresh(refreshToken: String) async throws -> AuthTokenResponse
    func me(accessToken: String) async throws -> AuthUserDTO
    func patchMe(accessToken: String, kbFolder: String) async throws -> AuthUserDTO
    func listNcFolders(accessToken: String, path: String) async throws -> AuthNcFoldersResponse
    func createNcFolder(accessToken: String, name: String, parent: String, select: Bool) async throws -> AuthNcFoldersResponse
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
            return String(localized: "auth.error_missing_api_url")
        case let .invalidResponse(statusCode, message):
            if statusCode == 401 || statusCode == 403 {
                return String(localized: "auth.session_expired")
            }
            if let message, !message.isEmpty {
                return message
            }
            return String(localized: "auth.session_expired")
        case .decodingFailed:
            return String(localized: "network.decoding_failed")
        }
    }

    /// True when the server rejected credentials / refresh (safe to clear local session).
    var isUnauthorized: Bool {
        if case let .invalidResponse(statusCode, _) = self {
            return statusCode == 401 || statusCode == 403
        }
        return false
    }

    /// Network / decode / 5xx must not wipe Keychain; only definitive auth rejection.
    static func isDefinitiveAuthFailure(_ error: Error) -> Bool {
        (error as? AuthAPIError)?.isUnauthorized == true
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

    func patchMe(accessToken: String, kbFolder: String) async throws -> AuthUserDTO {
        let envelope: AuthMeResponse = try await patch(
            path: "api/auth/me",
            body: ["kb_folder": kbFolder],
            accessToken: accessToken
        )
        return envelope.user
    }

    func listNcFolders(accessToken: String, path: String = "/") async throws -> AuthNcFoldersResponse {
        try await get(
            path: "api/auth/nc-folders",
            queryItems: [URLQueryItem(name: "path", value: path)],
            authorized: true,
            accessToken: accessToken
        )
    }

    func createNcFolder(
        accessToken: String,
        name: String,
        parent: String = "/",
        select: Bool
    ) async throws -> AuthNcFoldersResponse {
        try await post(
            path: "api/auth/nc-folders",
            body: ["name": name, "parent": parent, "select": select],
            authorized: true,
            accessToken: accessToken
        )
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
        queryItems: [URLQueryItem] = [],
        authorized: Bool,
        accessToken: String? = nil
    ) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw AuthAPIError.missingBaseURL
        }
        var request = URLRequest(url: url)
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

    private func patch<T: Decodable>(
        path: String,
        body: [String: Any],
        accessToken: String
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
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
