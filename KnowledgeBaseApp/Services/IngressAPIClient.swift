import Foundation

protocol IngressAPIClientProtocol: Sendable {
    func fetchTokens() async throws -> [IngressToken]
    func createToken(_ body: IngressCreateTokenBody) async throws -> IngressToken
    func revokeToken(id: String) async throws
    func fetchBindings() async throws -> [IngressBinding]
    func upsertBinding(key: String, sessionId: Int) async throws
    func fetchRules() async throws -> [IngressRule]
    func setRuleEnabled(id: String, enabled: Bool) async throws
    func fetchAdapters() async throws -> [IngressAdapter]
    func fetchEvents(limit: Int) async throws -> [IngressEvent]
}

enum IngressAPIError: Error, Equatable, LocalizedError {
    case missingBaseURL
    case invalidResponse(statusCode: Int, apiMessage: String?)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "API base URL is not configured"
        case .invalidResponse(let statusCode, let apiMessage):
            return apiMessage ?? "HTTP \(statusCode)"
        case .decodingFailed:
            return "Failed to decode ingress response"
        }
    }
}

struct IngressToken: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var label: String
    var description: String
    var channelId: String
    var adapterKey: String?
    var allowedSources: [String]?
    var allowEnqueueAgent: Bool
    var allowScript: Bool
    var agentRuntime: String
    var agentPromptProfile: String
    var tokenPrefix: String
    var revokedAt: String?
    var createdAt: String?
    var ingressPath: String?
    /// Present only on create response.
    var token: String?
    var ingressUrl: String?
    var ingressUrlPath: String?

    enum CodingKeys: String, CodingKey {
        case id, label, description, token
        case channelId = "channel_id"
        case adapterKey = "adapter_key"
        case allowedSources = "allowed_sources"
        case allowEnqueueAgent = "allow_enqueue_agent"
        case allowScript = "allow_script"
        case agentRuntime = "agent_runtime"
        case agentPromptProfile = "agent_prompt_profile"
        case tokenPrefix = "token_prefix"
        case revokedAt = "revoked_at"
        case createdAt = "created_at"
        case ingressPath = "ingress_path"
        case ingressUrl = "ingress_url"
        case ingressUrlPath = "ingress_url_path"
    }

    var isRevoked: Bool {
        guard let revokedAt, !revokedAt.isEmpty else { return false }
        return true
    }

    var maskedPrefix: String {
        let p = tokenPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        if p.isEmpty { return "…" }
        return p.count <= 8 ? "\(p)…" : "\(String(p.prefix(8)))…"
    }
}

struct IngressCreateTokenBody: Encodable {
    var label: String
    var description: String
    var channelId: String
    var adapterKey: String?
    var allowedSources: [String]?
    var allowEnqueueAgent: Bool
    var allowScript: Bool
    var agentRuntime: String
    var agentPromptProfile: String

    enum CodingKeys: String, CodingKey {
        case label, description
        case channelId = "channel_id"
        case adapterKey = "adapter_key"
        case allowedSources = "allowed_sources"
        case allowEnqueueAgent = "allow_enqueue_agent"
        case allowScript = "allow_script"
        case agentRuntime = "agent_runtime"
        case agentPromptProfile = "agent_prompt_profile"
    }
}

struct IngressBinding: Codable, Identifiable, Equatable, Hashable {
    var bindingKey: String
    var sessionId: Int
    var updatedAt: String?

    var id: String { bindingKey }

    enum CodingKeys: String, CodingKey {
        case bindingKey = "binding_key"
        case sessionId = "session_id"
        case updatedAt = "updated_at"
    }
}

struct IngressRule: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var label: String
    var priority: Int
    var enabled: Bool
    var match: [String: AnyCodableJSON]?
    var action: [String: AnyCodableJSON]?

    enum CodingKeys: String, CodingKey {
        case id, label, priority, enabled, match, action
    }

    var actionSummary: String {
        guard let action else { return "—" }
        let kind = action["kind"]?.stringValue ?? "?"
        let policy = action["policy"]?.stringValue ?? ""
        let key = action["session_key"]?.stringValue
        let sid = action["session_id"]?.stringValue
        var parts = [kind]
        if let key, !key.isEmpty { parts.append(key) }
        else if let sid, !sid.isEmpty { parts.append("#\(sid)") }
        if !policy.isEmpty { parts.append(policy) }
        return parts.joined(separator: " · ")
    }
}

struct IngressAdapter: Codable, Identifiable, Equatable, Hashable {
    var id: String { key }
    var key: String
    var label: String
    var participantKey: String?

    enum CodingKeys: String, CodingKey {
        case key, label
        case participantKey = "participant_key"
    }
}

struct IngressEvent: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var source: String
    var type: String
    var summary: String
    var status: String
    var channelId: String?
    var adapterKey: String?
    var createdAt: String?
    var errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case id, source, type, summary, status
        case channelId = "channel_id"
        case adapterKey = "adapter_key"
        case createdAt = "created_at"
        case errorMessage = "error_message"
    }
}

/// Minimal JSON-compatible value for rule match/action display (not a full editor).
enum AnyCodableJSON: Codable, Equatable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: AnyCodableJSON])
    case array([AnyCodableJSON])
    case null

    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([String: AnyCodableJSON].self) { self = .object(v); return }
        if let v = try? c.decode([AnyCodableJSON].self) { self = .array(v); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
}

final class URLSessionIngressAPIClient: IngressAPIClientProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let transport: KBHTTPTransport

    init(baseURL: URL, authToken: String?, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.transport = KBHTTPTransport(authToken: authToken, urlSession: urlSession)
    }

    convenience init?() {
        guard let base = AppConfiguration.url(for: AppConfiguration.Keys.apiBaseURL) else { return nil }
        let token = AppConfiguration.string(for: AppConfiguration.Keys.authToken)
        self.init(baseURL: base, authToken: token)
    }

    func fetchTokens() async throws -> [IngressToken] {
        let data = try await get("api/me/ingress/tokens")
        return try decode(TokensEnvelope.self, from: data).tokens
    }

    func createToken(_ body: IngressCreateTokenBody) async throws -> IngressToken {
        let data = try await post("api/me/ingress/tokens", body: body)
        return try decode(IngressToken.self, from: data)
    }

    func revokeToken(id: String) async throws {
        _ = try await post("api/me/ingress/tokens/\(id)/revoke", body: EmptyBody())
    }

    func fetchBindings() async throws -> [IngressBinding] {
        let data = try await get("api/me/ingress/bindings")
        return try decode(BindingsEnvelope.self, from: data).bindings
    }

    func upsertBinding(key: String, sessionId: Int) async throws {
        struct Body: Encodable {
            var binding_key: String
            var session_id: Int
        }
        _ = try await put("api/me/ingress/bindings", body: Body(binding_key: key, session_id: sessionId))
    }

    func fetchRules() async throws -> [IngressRule] {
        let data = try await get("api/me/ingress/rules")
        return try decode(RulesEnvelope.self, from: data).rules
    }

    func setRuleEnabled(id: String, enabled: Bool) async throws {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("api/me/ingress/rules/\(id)/enabled"),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "enabled", value: enabled ? "true" : "false")]
        guard let url = comps?.url else { throw IngressAPIError.missingBaseURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await transport.data(for: request)
        try Self.validate(response: response, data: data)
    }

    func fetchAdapters() async throws -> [IngressAdapter] {
        let data = try await get("api/me/ingress/adapters")
        return try decode(AdaptersEnvelope.self, from: data).adapters
    }

    func fetchEvents(limit: Int = 30) async throws -> [IngressEvent] {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("api/me/ingress/events"),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        guard let url = comps?.url else { throw IngressAPIError.missingBaseURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await transport.data(for: request)
        try Self.validate(response: response, data: data)
        return try decode(EventsEnvelope.self, from: data).events
    }

    private struct EmptyBody: Encodable {}
    private struct TokensEnvelope: Decodable { var tokens: [IngressToken] }
    private struct BindingsEnvelope: Decodable { var bindings: [IngressBinding] }
    private struct RulesEnvelope: Decodable { var rules: [IngressRule] }
    private struct AdaptersEnvelope: Decodable { var adapters: [IngressAdapter] }
    private struct EventsEnvelope: Decodable { var events: [IngressEvent] }

    private func get(_ path: String) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"
        let (data, response) = try await transport.data(for: request)
        try Self.validate(response: response, data: data)
        return data
    }

    private func post<T: Encodable>(_ path: String, body: T) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await transport.data(for: request)
        try Self.validate(response: response, data: data)
        return data
    }

    private func put<T: Encodable>(_ path: String, body: T) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await transport.data(for: request)
        try Self.validate(response: response, data: data)
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw IngressAPIError.decodingFailed
        }
    }

    private static func validate(response: HTTPURLResponse, data: Data) throws {
        guard (200 ..< 300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(KBAPIErrorEnvelope.self, from: data))?.error.message
            throw IngressAPIError.invalidResponse(statusCode: response.statusCode, apiMessage: message)
        }
    }
}

final class StubIngressAPIClient: IngressAPIClientProtocol, @unchecked Sendable {
    var tokens: [IngressToken] = []
    var bindings: [IngressBinding] = []
    var rules: [IngressRule] = []
    var adapters: [IngressAdapter] = []
    var events: [IngressEvent] = []

    func fetchTokens() async throws -> [IngressToken] { tokens }
    func createToken(_ body: IngressCreateTokenBody) async throws -> IngressToken {
        IngressToken(
            id: UUID().uuidString,
            label: body.label,
            description: body.description,
            channelId: body.channelId,
            adapterKey: body.adapterKey,
            allowedSources: body.allowedSources,
            allowEnqueueAgent: body.allowEnqueueAgent,
            allowScript: body.allowScript,
            agentRuntime: body.agentRuntime,
            agentPromptProfile: body.agentPromptProfile,
            tokenPrefix: "stub",
            revokedAt: nil,
            createdAt: nil,
            ingressPath: "/api/ingress/stub…",
            token: "stub-raw-token",
            ingressUrl: "https://example.test/api/ingress/stub-raw-token",
            ingressUrlPath: "/api/ingress/stub-raw-token"
        )
    }
    func revokeToken(id: String) async throws {
        tokens = tokens.map { t in
            var copy = t
            if copy.id == id { copy.revokedAt = "revoked" }
            return copy
        }
    }
    func fetchBindings() async throws -> [IngressBinding] { bindings }
    func upsertBinding(key: String, sessionId: Int) async throws {
        if let idx = bindings.firstIndex(where: { $0.bindingKey == key }) {
            bindings[idx].sessionId = sessionId
        } else {
            bindings.append(IngressBinding(bindingKey: key, sessionId: sessionId, updatedAt: nil))
        }
    }
    func fetchRules() async throws -> [IngressRule] { rules }
    func setRuleEnabled(id: String, enabled: Bool) async throws {
        rules = rules.map { r in
            var copy = r
            if copy.id == id { copy.enabled = enabled }
            return copy
        }
    }
    func fetchAdapters() async throws -> [IngressAdapter] { adapters }
    func fetchEvents(limit: Int) async throws -> [IngressEvent] { Array(events.prefix(limit)) }
}

private struct KBAPIErrorEnvelope: Decodable {
    struct ErrorBody: Decodable { var message: String? }
    var error: ErrorBody
}
