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
    let browsePath: String
    let parentPath: String?
    let hasNcAppPassword: Bool
    let folders: [AuthNcFolderDTO]

    enum CodingKeys: String, CodingKey {
        case current
        case browsePath = "browse_path"
        case parentPath = "parent_path"
        case hasNcAppPassword = "has_nc_app_password"
        case folders
    }

    init(
        current: String,
        browsePath: String = "/",
        parentPath: String? = nil,
        hasNcAppPassword: Bool,
        folders: [AuthNcFolderDTO]
    ) {
        self.current = current
        self.browsePath = browsePath
        self.parentPath = parentPath
        self.hasNcAppPassword = hasNcAppPassword
        self.folders = folders
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        current = try c.decode(String.self, forKey: .current)
        browsePath = try c.decodeIfPresent(String.self, forKey: .browsePath) ?? "/"
        parentPath = try c.decodeIfPresent(String.self, forKey: .parentPath)
        hasNcAppPassword = try c.decode(Bool.self, forKey: .hasNcAppPassword)
        folders = try c.decode([AuthNcFolderDTO].self, forKey: .folders)
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
