import XCTest
@testable import KnowledgeBaseApp

final class KBFileOpenLinkTests: XCTestCase {
    func testDecodesOpenLinkJSON() throws {
        let json = Data(
            """
            {
              "web_url": "https://cloud.example.com/f/42",
              "nextcloud_deeplink": "nextcloud://open-file?user=demo&link=https://cloud.example.com/index.php/f/42",
              "path": "a.md",
              "change_id": "7"
            }
            """.utf8
        )
        let link = try JSONDecoder().decode(KBFileOpenLink.self, from: json)
        XCTAssertEqual(link.webURL.absoluteString, "https://cloud.example.com/f/42")
        XCTAssertEqual(link.path, "a.md")
        XCTAssertEqual(
            link.nextcloudDeepLink?.scheme,
            "nextcloud"
        )
    }

    func testDecodesWithoutDeeplink() throws {
        let json = Data(
            """
            {"web_url":"https://cloud.example.com/apps/files/?dir=/KnowledgeBase","path":"x.md"}
            """.utf8
        )
        let link = try JSONDecoder().decode(KBFileOpenLink.self, from: json)
        XCTAssertNil(link.nextcloudDeepLink)
        XCTAssertEqual(link.path, "x.md")
    }
}
