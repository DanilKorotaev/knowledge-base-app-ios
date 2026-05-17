import XCTest
@testable import KnowledgeBaseApp

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// Live HTTP checks against a deployed KB App API. Skips unless `KB_E2E_*` env is set (see `docs/testing/E2E.md`).
final class KnowledgeBaseAPIE2ETests: XCTestCase {
    private func e2eBaseURLOrSkip() throws -> URL {
        let raw = e2eConfigValue(e2eKey: "KB_E2E_API_BASE_URL", plistKey: "KBAppAPIBaseURL", appKey: "API_BASE_URL")
        guard !raw.isEmpty, let url = URL(string: raw) else {
            throw XCTSkip("Set KB_E2E_* or run ./scripts/sync-secrets-xcconfig.sh (see docs/testing/E2E.md)")
        }
        return url
    }

    private func e2eAuthOrSkip() throws -> (baseURL: URL, token: String) {
        let baseURL = try e2eBaseURLOrSkip()
        let token = e2eConfigValue(e2eKey: "KB_E2E_API_TOKEN", plistKey: "KBAppAuthToken", appKey: "AUTH_TOKEN")
        guard !token.isEmpty else {
            throw XCTSkip("Set KB_E2E_API_TOKEN or KBAPP_AUTH_TOKEN / Secrets.xcconfig")
        }
        return (baseURL, token)
    }

    /// E2E env → test bundle Info.plist (from Secrets.xcconfig) → same keys as the app (`KBAPP_*` env).
    private func e2eConfigValue(e2eKey: String, plistKey: String, appKey: String) -> String {
        let env = ProcessInfo.processInfo.environment
        if let v = env[e2eKey]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty { return v }
        if let v = (Bundle.main.object(forInfoDictionaryKey: plistKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty { return v }
        let appEnv = "KBAPP_\(appKey)"
        if let v = env[appEnv]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty { return v }
        return ""
    }

    func testHealthUnauthenticated() async throws {
        let baseURL = try e2eBaseURLOrSkip()
        let healthURL = baseURL.appendingPathComponent("health")
        var request = URLRequest(url: healthURL)
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: request)
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 200, "GET /health body: \(String(data: data, encoding: .utf8) ?? "")")
    }

    func testSessionLifecycle() async throws {
        let (baseURL, token) = try e2eAuthOrSkip()
        let client = URLSessionKnowledgeBaseAPIClient(
            baseURL: baseURL,
            authToken: token,
            urlSession: .shared,
            useE2EIntegrationUser: true
        )

        let created = try await client.createSession(title: "E2E \(UUID().uuidString.prefix(8))")
        XCTAssertFalse(created.id.isEmpty)

        let sessions = try await client.fetchSessions()
        XCTAssertTrue(sessions.contains { $0.id == created.id }, "New session should appear in GET /api/sessions")

        let messages = try await client.sendTextMessage(
            sessionId: created.id,
            text: "e2e ping",
            useKnowledgeBase: false
        )
        XCTAssertFalse(messages.isEmpty, "POST …/messages should return assistant messages (or non-empty list)")
    }
}
