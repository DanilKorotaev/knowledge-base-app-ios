import XCTest
@testable import KnowledgeBaseApp

/// Live HTTP checks against a deployed KB App API. Skips unless `KB_E2E_*` env is set (see `docs/testing/E2E.md`).
final class KnowledgeBaseAPIE2ETests: XCTestCase {
    private func e2eBaseURLOrSkip() throws -> URL {
        let raw = ProcessInfo.processInfo.environment["KB_E2E_API_BASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty, let url = URL(string: raw) else {
            throw XCTSkip("Set KB_E2E_API_BASE_URL (see docs/testing/E2E.md)")
        }
        return url
    }

    private func e2eAuthOrSkip() throws -> (baseURL: URL, token: String) {
        let baseURL = try e2eBaseURLOrSkip()
        let token = ProcessInfo.processInfo.environment["KB_E2E_API_TOKEN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty else {
            throw XCTSkip("Set KB_E2E_API_TOKEN (see docs/testing/E2E.md)")
        }
        return (baseURL, token)
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
        let client = URLSessionKnowledgeBaseAPIClient(baseURL: baseURL, authToken: token, urlSession: .shared)

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
