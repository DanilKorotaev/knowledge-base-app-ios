import XCTest
@testable import KnowledgeBaseApp

final class KnowledgeBaseAPIClientTests: XCTestCase {
    func testStubReturnsEmptySessions() async throws {
        let client = StubKnowledgeBaseAPIClient()
        let sessions = try await client.fetchSessions()
        XCTAssertTrue(sessions.isEmpty)
    }

    func testRemoteClientSuccessDecodesArray() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let json = """
        [{"id":"1","title":"One","message_count":2}]
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
            XCTAssertTrue(request.url?.absoluteString.hasSuffix("/api/sessions") == true)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json)
        }

        let base = URL(string: "https://kb.test")!
        let client = URLSessionKnowledgeBaseAPIClient(baseURL: base, authToken: "tok", urlSession: URLSession(configuration: config))
        let sessions = try await client.fetchSessions()

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].title, "One")
        MockURLProtocol.requestHandler = nil
    }

    func testRemoteClientNon2xxThrows() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let base = URL(string: "https://kb.test")!
        let client = URLSessionKnowledgeBaseAPIClient(baseURL: base, authToken: nil, urlSession: URLSession(configuration: config))

        do {
            _ = try await client.fetchSessions()
            XCTFail("expected error")
        } catch KnowledgeBaseAPIError.invalidResponse(let code) {
            XCTAssertEqual(code, 503)
        }

        MockURLProtocol.requestHandler = nil
    }
}

// MARK: - Test URLProtocol

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badURL)
            )
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
