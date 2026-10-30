@testable import KnowledgeBaseApp
import XCTest

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

    func testDecodeComposeCamera() throws {
        let action = try JSONDecoder().decode(
            KBAppAction.self,
            from: Data(
                #"{"type":"compose_camera","message":"запиши питание по фото"}"#.utf8
            )
        )
        XCTAssertEqual(action.type, "compose_camera")
        XCTAssertEqual(action.message, "запиши питание по фото")
        XCTAssertNil(action.sessionId)
    }

    func testDecodeRemoteUIShareDestination() throws {
        let action = try JSONDecoder().decode(
            KBAppAction.self,
            from: Data(
                #"""
                {
                  "type": "remote_ui",
                  "url": "/api/remote-ui/lyrics/v1/ui/from-share?url={{shared_url}}&text={{shared_text}}",
                  "title": "Текст песни",
                  "share": true,
                  "share_label": "Текст песни"
                }
                """#.utf8
            )
        )
        XCTAssertEqual(action.type, "remote_ui")
        XCTAssertEqual(action.share, true)
        XCTAssertTrue(action.isShareDestination)
        XCTAssertEqual(action.shareLabel, "Текст песни")
        let resolved = RemoteUIURLBuilder.resolveTemplate(
            action.url,
            sharedURL: "https://music.yandex.ru/track/1",
            sharedText: "Artist - Song"
        )
        XCTAssertTrue(resolved?.contains("music.yandex.ru") == true)
        XCTAssertTrue(resolved?.contains("Artist") == true)
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

    func testSparseAxisKeepsEnds() {
        let labels = (0..<90).map { String(format: "2026-01-%02d", ($0 % 28) + 1) }
        let ticks = StructuredUIChartDisplay.sparseAxisValues(from: labels, count: 3)
        XCTAssertEqual(ticks.count, 3)
        XCTAssertEqual(ticks.first, labels.first)
        XCTAssertEqual(ticks.last, labels.last)
    }
}
