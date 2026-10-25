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
    let kbFolder: String?
    let hasNcAppPassword: Bool?

    enum CodingKeys: String, CodingKey {
        case id, login, email, role
        case mustChangePassword = "must_change_password"
        case cursorIsolation = "cursor_isolation"
        case vaultRootRelative = "vault_root_relative"
        case nextcloudUsername = "nextcloud_username"
        case kbFolder = "kb_folder"
        case hasNcAppPassword = "has_nc_app_password"
    }
}

struct AuthNcFolderDTO: Codable, Equatable, Sendable, Identifiable {
    let path: String
    let name: String

    var id: String { path }
}

struct AuthNcFoldersResponse: Codable, Equatable, Sendable {
    let current: String
    let hasNcAppPassword: Bool
    let folders: [AuthNcFolderDTO]

    enum CodingKeys: String, CodingKey {
        case current
        case hasNcAppPassword = "has_nc_app_password"
        case folders
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
