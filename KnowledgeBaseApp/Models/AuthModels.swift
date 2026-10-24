import Foundation

struct AuthUserDTO: Codable, Equatable, Sendable {
    let id: Int
    let login: String
    let email: String?
    let role: String?
    let mustChangePassword: Bool
    let cursorIsolation: String?
    let vaultRootRelative: String?
    let nextcloudUsername: String?

    enum CodingKeys: String, CodingKey {
        case id, login, email, role
        case mustChangePassword = "must_change_password"
        case cursorIsolation = "cursor_isolation"
        case vaultRootRelative = "vault_root_relative"
        case nextcloudUsername = "nextcloud_username"
    }
}

struct AuthTokenResponse: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String?
    let expiresIn: Int?
    let user: AuthUserDTO

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }
}

struct AuthSignupStatus: Codable, Equatable, Sendable {
    let openSignup: Bool

    enum CodingKeys: String, CodingKey {
        case openSignup = "open_signup"
    }
}

struct AuthMeResponse: Codable, Equatable, Sendable {
    let user: AuthUserDTO
}
