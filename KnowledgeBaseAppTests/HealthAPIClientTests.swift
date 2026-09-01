import Foundation
import Testing
@testable import KnowledgeBaseApp

@Suite("HealthAPIClient")
struct HealthAPIClientTests {
    private func makeClient() -> (URLSessionHealthAPIClient, URLSession) {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = URLSessionHealthAPIClient(
            baseURL: URL(string: "https://kb.test")!,
            authToken: "token",
            urlSession: session
        )
        return (client, session)
    }

    @Test("fetchSettings decodes health_data_relative")
    func fetchSettings() async throws {
        let (client, _) = makeClient()
        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.path.hasSuffix("/api/me/settings") == true)
            #expect(request.httpMethod == "GET")
            let body = #"{"health_data_relative":"HealthData/custom"}"#.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let settings = try await client.fetchSettings()
        #expect(settings.healthDataRelative == "HealthData/custom")
    }

    @Test("fetchSyncState returns nil on 404")
    func fetchSyncStateNotFound() async throws {
        let (client, _) = makeClient()
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        defer { MockURLProtocol.requestHandler = nil }

        let state = try await client.fetchSyncState()
        #expect(state == nil)
    }

    @Test("uploadSyncFiles posts JSON batch")
    func uploadSyncFiles() async throws {
        let (client, _) = makeClient()
        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path.hasSuffix("/api/health/sync/files") == true)
            let body = #"{"written":["daily/2026-01-01.json"],"synced_to_nextcloud":true}"#.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let result = try await client.uploadSyncFiles([
            HealthSyncFileUpload(path: "daily/2026-01-01.json", data: Data("{}".utf8)),
        ])
        #expect(result.written == ["daily/2026-01-01.json"])
        #expect(result.syncedToNextcloud)
    }

    @Test("updateSettings sends PATCH body")
    func updateSettings() async throws {
        let (client, _) = makeClient()
        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "PATCH")
            let body = #"{"health_data_relative":"HealthData"}"#.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let settings = try await client.updateSettings(healthDataRelative: "HealthData")
        #expect(settings.healthDataRelative == "HealthData")
    }
}
