import XCTest
@testable import KnowledgeBaseApp

final class KnowledgeBaseAPIClientTests: XCTestCase {
    func testStubReturnsEmptySessionsWhenStoreHasNoSessions() async throws {
        let store = InMemoryKBStore(demoSession: false)
        let client = StubKnowledgeBaseAPIClient(store: store)
        let sessions = try await client.fetchSessions()
        XCTAssertTrue(sessions.isEmpty)
    }

    func testStubDefaultStoreIncludesDemoSession() async throws {
        let client = StubKnowledgeBaseAPIClient()
        let sessions = try await client.fetchSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, "demo-session")
    }

    func testStubCreateSessionAppendsToStore() async throws {
        let store = InMemoryKBStore(demoSession: false)
        let client = StubKnowledgeBaseAPIClient(store: store)
        let created = try await client.createSession(title: "Alpha")
        XCTAssertEqual(created.title, "Alpha")
        let sessions = try await client.fetchSessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.title, "Alpha")
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
        } catch let error as KnowledgeBaseAPIError {
            if case let .invalidResponse(code, message) = error {
                XCTAssertEqual(code, 503)
                XCTAssertNil(message)
            } else {
                XCTFail("unexpected \(error)")
            }
        }

        MockURLProtocol.requestHandler = nil
    }

    func testKBChangedFileDecodesSnakeCaseJSON() throws {
        let json = """
        {"id":"c1","path":"a.md","change_kind":"modified","before_text":null,"after_text":"# x"}
        """.data(using: .utf8)!
        let file = try JSONDecoder().decode(KBChangedFile.self, from: json)
        XCTAssertEqual(file.changeKind, "modified")
        XCTAssertEqual(file.afterText, "# x")
    }

    func testRemoteClientNon2xxDecodesErrorEnvelopeMessage() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let body = """
        {"error":{"code":"rate_limit","message":"Slow down","detail":null}}
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }

        let base = URL(string: "https://kb.test")!
        let client = URLSessionKnowledgeBaseAPIClient(baseURL: base, authToken: nil, urlSession: URLSession(configuration: config))

        do {
            _ = try await client.fetchSessions()
            XCTFail("expected error")
        } catch let error as KnowledgeBaseAPIError {
            if case let .invalidResponse(code, message) = error {
                XCTAssertEqual(code, 429)
                XCTAssertEqual(message, "Slow down")
            } else {
                XCTFail("unexpected \(error)")
            }
        }

        MockURLProtocol.requestHandler = nil
    }

    func testVoiceUploadDecodesTranscriptionField() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        let payload = """
        {"messages":[{"id":"m1","role":"user","content":"voice","created_at":"2026-01-01T12:00:00Z"}],"transcription":"Hello from Whisper"}
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url?.path.contains("/api/query/voice") == true)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, payload)
        }

        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("voice-\(UUID().uuidString).m4a")
        try Data([0, 1, 2]).write(to: temp)
        defer { try? FileManager.default.removeItem(at: temp) }

        let base = URL(string: "https://kb.test")!
        let client = URLSessionKnowledgeBaseAPIClient(baseURL: base, authToken: "tok", urlSession: URLSession(configuration: config))
        let result = try await client.sendVoiceRecording(
            sessionId: "demo-session",
            audioFileURL: temp,
            transcriptionHint: "",
            useKnowledgeBase: true
        )

        XCTAssertEqual(result.transcription, "Hello from Whisper")
        XCTAssertEqual(result.messages.count, 1)
        XCTAssertEqual(result.messages[0].content, "voice")

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
