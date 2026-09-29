import XCTest
@testable import KnowledgeBaseApp

final class KBAppActionTests: XCTestCase {
    func testDecodeOpenSessionAction() throws {
        let json = Data(#"{"type":"open_session","session_id":"264"}"#.utf8)
        let action = try JSONDecoder().decode(KBAppAction.self, from: json)
        XCTAssertEqual(action.type, "open_session")
        XCTAssertEqual(action.sessionId, "264")
    }

    func testDecodeOpenBoardAndTab() throws {
        let board = try JSONDecoder().decode(
            KBAppAction.self,
            from: Data(#"{"type":"open_board","board_id":"health"}"#.utf8)
        )
        XCTAssertEqual(board.boardId, "health")

        let tab = try JSONDecoder().decode(
            KBAppAction.self,
            from: Data(#"{"type":"open_tab","tab":"settings"}"#.utf8)
        )
        XCTAssertEqual(tab.resolvedTab, .settings)
    }

    func testMetricNodeKeepsTextWithAction() throws {
        let json = Data("""
        {
          "schema_version": 1,
          "screen": {
            "type": "metric",
            "id": "session",
            "label": "Session",
            "text": "264",
            "action": {"type": "open_session", "session_id": "264"}
          }
        }
        """.utf8)
        let document = try JSONDecoder().decode(KBStructuredUIDocument.self, from: json)
        XCTAssertEqual(document.screen.text, "264")
        XCTAssertEqual(document.screen.action?.type, "open_session")
        XCTAssertEqual(document.screen.action?.sessionId, "264")
        XCTAssertTrue(document.hasAppActions)
    }

    func testChartAxisLabelFormatsISODate() {
        let label = StructuredUIChartDisplay.axisLabel(from: "2026-03-15")
        XCTAssertFalse(label.contains("2026-03-15"))
        XCTAssertFalse(label.isEmpty)
    }
}
