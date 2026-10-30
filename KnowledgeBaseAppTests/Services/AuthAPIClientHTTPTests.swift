@testable import KnowledgeBaseApp
import XCTest

/// URLProtocol stub for AuthAPIClient network paths.
final class AuthAPIClientHTTPTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AuthURLProtocol.requestHandler = nil
    }

    override func tearDown() {
        AuthURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testLoginDecodesTokens() async throws {
        AuthURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/login")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = """
            {
              "access_token":"a1",
              "refresh_token":"r1",
              "token_type":"bearer",
              "expires_in":3600,
              "user":{
                "id":3,
                "login":"carol",
                "email":null,
                "role":"user",
                "must_change_password":false,
                "cursor_isolation":"strict",
                "vault_root_relative":"users/carol",
                "nextcloud_username":"carol"
              }
            }
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, body)
        }

        let client = URLSessionAuthAPIClient(
            baseURL: URL(string: "https://example.test")!,
            urlSession: Self.stubSession()
        )
        let tokens = try await client.login(login: "carol", password: "secret-pass")
        XCTAssertEqual(tokens.accessToken, "a1")
        XCTAssertEqual(tokens.user.login, "carol")
        XCTAssertEqual(tokens.user.vaultRootRelative, "users/carol")
    }

    func testSignupStatus() async throws {
        AuthURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.path.hasSuffix("/api/auth/signup-status") == true)
            let body = #"{"open_signup":true}"#.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }
        let client = URLSessionAuthAPIClient(
            baseURL: URL(string: "https://example.test")!,
            urlSession: Self.stubSession()
        )
        let status = try await client.signupStatus()
        XCTAssertTrue(status.openSignup)
    }

    func testLoginMapsHTTPError() async {
        AuthURLProtocol.requestHandler = { request in
            let body = #"{"detail":"Неверный логин или пароль"}"#.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }
        let client = URLSessionAuthAPIClient(
            baseURL: URL(string: "https://example.test")!,
            urlSession: Self.stubSession()
        )
        do {
            _ = try await client.login(login: "x", password: "y")
            XCTFail("expected error")
        } catch let error as AuthAPIError {
            guard case let .invalidResponse(code, message) = error else {
                return XCTFail("wrong case \(error)")
            }
            XCTAssertEqual(code, 401)
            XCTAssertEqual(message, "Неверный логин или пароль")
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    func testMeRequiresBearer() async throws {
        AuthURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
            let body = """
            {"user":{"id":1,"login":"a","email":null,"role":"user","must_change_password":false,
             "cursor_isolation":"strict","vault_root_relative":"users/a","nextcloud_username":"a"}}
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }
        let client = URLSessionAuthAPIClient(
            baseURL: URL(string: "https://example.test")!,
            urlSession: Self.stubSession()
        )
        let user = try await client.me(accessToken: "tok")
        XCTAssertEqual(user.login, "a")
    }

    private static func stubSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthURLProtocol.self]
        return URLSession(configuration: config)
    }
}

private final class AuthURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = AuthURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
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
