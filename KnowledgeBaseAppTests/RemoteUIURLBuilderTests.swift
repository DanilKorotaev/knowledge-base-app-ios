@testable import KnowledgeBaseApp
import XCTest

final class RemoteUIURLBuilderTests: XCTestCase {
    func testTemplateFormValues() {
        let resolved = RemoteUIURLBuilder.resolveTemplate(
            "/api/remote-ui/lyrics/v1/ui/search?q={{q}}",
            formValues: ["q": .string("still alive")]
        )
        XCTAssertEqual(resolved, "/api/remote-ui/lyrics/v1/ui/search?q=still%20alive")
    }

    func testAbsoluteAgainstAPIBase() throws {
        let base = try XCTUnwrap(URL(string: "https://kbapp.example"))
        let url = RemoteUIURLBuilder.absoluteURL(
            from: "/api/remote-ui/lyrics/v1/ui/home",
            apiBaseURL: base
        )
        XCTAssertEqual(url?.absoluteString, "https://kbapp.example/api/remote-ui/lyrics/v1/ui/home")
    }
}

final class RemoteUIDeepLinkTests: XCTestCase {
    func testRoundTrip() throws {
        let url = try XCTUnwrap(
            RemoteUIDeepLink.makeURL(
                targetURL: "http://127.0.0.1:8095/v1/ui/from-share?url=https%3A%2F%2Fmusic.yandex.ru%2Ftrack%2F1",
                title: "Текст песни"
            )
        )
        XCTAssertEqual(url.scheme, "knowledgebase")
        XCTAssertEqual(url.host, "remote-ui")
        let parsed = try XCTUnwrap(RemoteUIDeepLink.parse(url))
        XCTAssertTrue(parsed.url.contains("127.0.0.1:8095"))
        XCTAssertEqual(parsed.title, "Текст песни")
    }
}
