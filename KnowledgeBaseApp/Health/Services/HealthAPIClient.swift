import Foundation

protocol HealthAPIClientProtocol: Sendable {
    func fetchSettings() async throws -> HealthUserSettings
    func updateSettings(healthDataRelative: String) async throws -> HealthUserSettings
    func fetchSyncState() async throws -> SyncState?
    func uploadSyncFiles(_ files: [HealthSyncFileUpload]) async throws -> HealthSyncUploadResult
}

struct HealthUserSettings: Codable, Equatable {
    var healthDataRelative: String

    enum CodingKeys: String, CodingKey {
        case healthDataRelative = "health_data_relative"
    }
}

struct HealthSyncFileUpload: Equatable {
    var path: String
    var data: Data
}

struct HealthSyncUploadResult: Codable, Equatable {
    var written: [String]
    var syncedToNextcloud: Bool

    enum CodingKeys: String, CodingKey {
        case written
        case syncedToNextcloud = "synced_to_nextcloud"
    }
}

enum HealthAPIError: Error, Equatable {
    case missingBaseURL
    case invalidResponse(statusCode: Int, apiMessage: String? = nil)
    case decodingFailed
    case syncStateNotFound
}

final class URLSessionHealthAPIClient: HealthAPIClientProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let transport: KBHTTPTransport

    init(
        baseURL: URL,
        authToken: String?,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.transport = KBHTTPTransport(authToken: authToken, urlSession: urlSession)
    }

    convenience init?() {
        guard let base = AppConfiguration.url(for: AppConfiguration.Keys.apiBaseURL) else { return nil }
        let token = AppConfiguration.string(for: AppConfiguration.Keys.authToken)
        self.init(baseURL: base, authToken: token)
    }

    func fetchSettings() async throws -> HealthUserSettings {
        let url = baseURL.appendingPathComponent("api/me/settings")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await transport.data(for: request)
        try Self.validate(response: response, data: data)
        guard let decoded = try? JSONDecoder().decode(HealthUserSettings.self, from: data) else {
            throw HealthAPIError.decodingFailed
        }
        return decoded
    }

    func updateSettings(healthDataRelative: String) async throws -> HealthUserSettings {
        let url = baseURL.appendingPathComponent("api/me/settings")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["health_data_relative": healthDataRelative])
        let (data, response) = try await transport.data(for: request)
        try Self.validate(response: response, data: data)
        guard let decoded = try? JSONDecoder().decode(HealthUserSettings.self, from: data) else {
            throw HealthAPIError.decodingFailed
        }
        return decoded
    }

    func fetchSyncState() async throws -> SyncState? {
        let url = baseURL.appendingPathComponent("api/health/sync/state")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await transport.data(for: request)
        if response.statusCode == 404 {
            return nil
        }
        try Self.validate(response: response, data: data)
        guard let decoded = try? JSONDecoder().decode(SyncState.self, from: data) else {
            throw HealthAPIError.decodingFailed
        }
        return decoded
    }

    func uploadSyncFiles(_ files: [HealthSyncFileUpload]) async throws -> HealthSyncUploadResult {
        let url = baseURL.appendingPathComponent("api/health/sync/files")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = [
            "files": files.map { file in
                [
                    "path": file.path,
                    "content_base64": file.data.base64EncodedString(),
                ]
            },
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await transport.data(for: request)
        try Self.validate(response: response, data: data)
        guard let decoded = try? JSONDecoder().decode(HealthSyncUploadResult.self, from: data) else {
            throw HealthAPIError.decodingFailed
        }
        return decoded
    }

    private static func validate(response: HTTPURLResponse, data: Data) throws {
        guard (200 ..< 300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(KBAPIErrorEnvelope.self, from: data))?.error.message
            throw HealthAPIError.invalidResponse(statusCode: response.statusCode, apiMessage: message)
        }
    }
}

final class StubHealthAPIClient: HealthAPIClientProtocol, @unchecked Sendable {
    var settings = HealthUserSettings(healthDataRelative: "HealthData")
    var syncState: SyncState?
    var uploadedFiles: [HealthSyncFileUpload] = []

    func fetchSettings() async throws -> HealthUserSettings { settings }

    func updateSettings(healthDataRelative: String) async throws -> HealthUserSettings {
        var copy = settings
        copy.healthDataRelative = healthDataRelative
        return copy
    }

    func fetchSyncState() async throws -> SyncState? { syncState }

    func uploadSyncFiles(_ files: [HealthSyncFileUpload]) async throws -> HealthSyncUploadResult {
        uploadedFiles.append(contentsOf: files)
        return HealthSyncUploadResult(written: files.map(\.path), syncedToNextcloud: false)
    }
}

private struct KBAPIErrorEnvelope: Decodable {
    struct ErrorBody: Decodable {
        var message: String?
    }

    var error: ErrorBody
}
