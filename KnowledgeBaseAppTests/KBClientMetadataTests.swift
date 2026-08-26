import XCTest
@testable import KnowledgeBaseApp
import Alamofire

final class KBClientMetadataTests: XCTestCase {
    func testApplySetsVersionHeadersAndUserAgent() {
        var request = URLRequest(url: URL(string: "https://kb.test/api/sessions")!)
        let meta = KBClientMetadata(
            appVersion: "1.2.3",
            buildNumber: "99",
            platform: "ios",
            osVersion: "18.5"
        )
        meta.apply(to: &request)

        XCTAssertEqual(request.value(forHTTPHeaderField: KBClientMetadata.versionHeader), "1.2.3")
        XCTAssertEqual(request.value(forHTTPHeaderField: KBClientMetadata.buildHeader), "99")
        XCTAssertEqual(request.value(forHTTPHeaderField: KBClientMetadata.platformHeader), "ios")
        XCTAssertEqual(request.value(forHTTPHeaderField: KBClientMetadata.osHeader), "18.5")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "User-Agent"),
            "KnowledgeBaseApp/1.2.3 (ios 18.5; build 99)"
        )
    }

    func testInterceptorAddsClientMetadata() {
        let expectation = expectation(description: "adapt")
        let meta = KBClientMetadata(
            appVersion: "2.0.0",
            buildNumber: "7",
            platform: "ios",
            osVersion: "26.0"
        )
        let interceptor = KBRequestInterceptor(
            requestId: "test",
            authToken: "secret",
            useE2EIntegrationUser: false,
            clientMetadata: meta,
            apiLogger: KBApiLogger(logger: makeLogger(tags: [.network]))
        )

        let original = URLRequest(url: URL(string: "https://kb.test/api/health")!)
        interceptor.adapt(original, for: Session()) { result in
            switch result {
            case .success(let request):
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
                XCTAssertEqual(request.value(forHTTPHeaderField: KBClientMetadata.versionHeader), "2.0.0")
                XCTAssertEqual(request.value(forHTTPHeaderField: KBClientMetadata.buildHeader), "7")
                XCTAssertEqual(
                    request.value(forHTTPHeaderField: "User-Agent"),
                    "KnowledgeBaseApp/2.0.0 (ios 26.0; build 7)"
                )
            case .failure(let error):
                XCTFail("adapt failed: \(error)")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}
