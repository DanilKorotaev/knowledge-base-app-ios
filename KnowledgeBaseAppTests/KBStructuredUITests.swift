import XCTest
@testable import KnowledgeBaseApp

final class KBStructuredUITests: XCTestCase {
    func testDecodeStructuredUIDocument() throws {
        let json = """
        {
          "schema_version": 1,
          "screen": {
            "type": "vstack",
            "id": "root",
            "children": [
              {"type": "text", "id": "title", "text": "Hello"},
              {"type": "button", "id": "btn", "label": "Go", "action_id": "go"}
            ]
          }
        }
        """.data(using: .utf8)!

        let document = try JSONDecoder().decode(KBStructuredUIDocument.self, from: json)
        XCTAssertEqual(document.schemaVersion, 1)
        XCTAssertEqual(document.screen.type, "vstack")
        XCTAssertEqual(document.screen.supportedChildren.count, 2)
        XCTAssertTrue(document.isSupportedByClient)
    }

    func testDecodeMessageWithStructuredUI() throws {
        let json = """
        {
          "id": "1",
          "role": "assistant",
          "content": "Interactive UI ready.",
          "structured_ui": {
            "schema_version": 1,
            "screen": {
              "type": "vstack",
              "id": "root",
              "children": [
                {"type": "button", "id": "btn_yes", "label": "Yes", "action_id": "confirm_yes"}
              ]
            }
          }
        }
        """.data(using: .utf8)!

        let message = try JSONDecoder().decode(KBMessage.self, from: json)
        XCTAssertEqual(message.structuredUI?.screen.type, "vstack")
        XCTAssertEqual(message.structuredUI?.screen.supportedChildren.first?.actionId, "confirm_yes")
    }

    func testUnsupportedSchemaVersionFlag() throws {
        let document = KBStructuredUIDocument(
            schemaVersion: 99,
            screen: KBStructuredUINode(
                type: "vstack",
                id: "root",
                text: nil,
                label: nil,
                actionId: nil,
                children: []
            )
        )
        XCTAssertFalse(document.isSupportedByClient)
    }

    func testStubMockFlowStart() {
        let result = StubStructuredUIMockFlow.apply(actionId: "start", componentId: "bootstrap")
        XCTAssertNil(result.userContent)
        XCTAssertEqual(result.screen.screen.type, "vstack")
        XCTAssertEqual(result.screen.screen.supportedChildren.filter { $0.type == "button" }.count, 3)
    }

    func testFormSubmitSendsValuesSummary() {
        let values: [String: StructuredUIFormValue] = [
            "notify": .bool(true),
            "theme": .string("dark"),
            "topics": .strings(["ios", "bot"]),
            "note": .string("hi"),
        ]
        let result = StubStructuredUIMockFlow.apply(
            actionId: "submit_form",
            componentId: "btn_submit",
            values: values
        )
        XCTAssertEqual(result.userContent, "[UI] note=hi; notify=true; theme=dark; topics=[ios,bot]")
        XCTAssertEqual(
            result.screen.screen.supportedChildren.first(where: { $0.type == "text" })?.text,
            "Submitted"
        )
    }

    func testFormDraftSeedFromDocument() {
        let open = StubStructuredUIMockFlow.apply(actionId: "open_form", componentId: "btn_form")
        let seeded = StructuredUIFormDraft.seed(from: open.screen)
        XCTAssertEqual(seeded["notify"], .bool(true))
        XCTAssertEqual(seeded["theme"], .string("system"))
        XCTAssertEqual(seeded["topics"], .strings(["ios"]))
        XCTAssertEqual(seeded["note"], .string(""))
    }

    func testDecodeMediaAndDividerNodes() throws {
        let json = """
        {
          "schema_version": 1,
          "screen": {
            "type": "vstack",
            "id": "root",
            "children": [
              {"type": "text", "id": "t", "text": "Media"},
              {"type": "divider", "id": "d1"},
              {
                "type": "image",
                "id": "img1",
                "url": "https://example.com/a.png",
                "alt": "Sample",
                "content_mode": "fit"
              },
              {
                "type": "image",
                "id": "img2",
                "download_url": "/api/attachments/1/download",
                "alt": "Auth image"
              },
              {
                "type": "link",
                "id": "lnk1",
                "url": "https://example.com/docs",
                "label": "Docs"
              },
              {
                "type": "file",
                "id": "file1",
                "download_url": "/api/attachments/2/download",
                "file_name": "notes.pdf",
                "file_size": 2048,
                "label": "Notes"
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let document = try JSONDecoder().decode(KBStructuredUIDocument.self, from: json)
        let types = document.screen.supportedChildren.map(\.type)
        XCTAssertEqual(types, ["text", "divider", "image", "image", "link", "file"])
        XCTAssertEqual(document.screen.supportedChildren[2].url, "https://example.com/a.png")
        XCTAssertEqual(document.screen.supportedChildren[2].alt, "Sample")
        XCTAssertEqual(document.screen.supportedChildren[3].downloadURL, "/api/attachments/1/download")
        XCTAssertEqual(document.screen.supportedChildren[4].label, "Docs")
        XCTAssertEqual(document.screen.supportedChildren[5].fileName, "notes.pdf")
        XCTAssertEqual(document.screen.supportedChildren[5].fileSize, 2048)
        XCTAssertTrue(document.screen.supportedChildren.allSatisfy(\.isSupported))
    }

    func testURLPolicyAllowsHTTPSAndRejectsJavascript() {
        XCTAssertNotNil(StructuredUIURLPolicy.allowedHTTPURL(from: "https://example.com/a"))
        XCTAssertNotNil(StructuredUIURLPolicy.allowedHTTPURL(from: "http://127.0.0.1:8091/x"))
        XCTAssertNil(StructuredUIURLPolicy.allowedHTTPURL(from: "javascript:alert(1)"))
        XCTAssertNil(StructuredUIURLPolicy.allowedHTTPURL(from: "file:///etc/passwd"))
        XCTAssertNil(StructuredUIURLPolicy.allowedHTTPURL(from: "kbapp://open"))
        XCTAssertTrue(StructuredUIURLPolicy.isAllowedDownloadPath("/api/attachments/1/download"))
        XCTAssertTrue(StructuredUIURLPolicy.isAllowedDownloadPath("api/sessions/1/attachments/2"))
        XCTAssertFalse(StructuredUIURLPolicy.isAllowedDownloadPath("../secret"))
        XCTAssertFalse(StructuredUIURLPolicy.isAllowedDownloadPath("javascript:alert(1)"))
    }

    func testResourceFetcherUsesAuthOnlyForAPIHost() {
        let loader = StubAttachmentLoader()
        XCTAssertFalse(
            StructuredUIResourceFetcher.shouldUseAuthenticatedLoader(
                for: "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
                loader: loader
            )
        )
        XCTAssertTrue(
            StructuredUIResourceFetcher.shouldUseAuthenticatedLoader(
                for: "/api/attachments/1/download",
                loader: loader
            )
        )
        XCTAssertTrue(
            StructuredUIResourceFetcher.shouldUseAuthenticatedLoader(
                for: "api/sessions/1/attachments/2",
                loader: loader
            )
        )
    }

    func testStructuredUIErrorMessageSanitizesJSON() {
        let error = NSError(domain: "test", code: 404, userInfo: [
            NSLocalizedDescriptionKey: #"{"detail":"Not Found"}"#,
        ])
        XCTAssertEqual(
            StructuredUIErrorMessage.userFacing(error),
            L10n.string("structured_ui.media_load_failed")
        )
    }
}
