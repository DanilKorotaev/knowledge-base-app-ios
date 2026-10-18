import XCTest
@testable import KnowledgeBaseApp

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
