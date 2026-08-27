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
}
