import XCTest
@testable import KnowledgeBaseApp

final class KBMessageTests: XCTestCase {
    func testDecodeMessageJSON() throws {
        let json = """
        {"id":"m1","role":"user","content":"Hello","created_at":"2026-04-04T12:00:00Z"}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let message = try decoder.decode(KBMessage.self, from: json)

        XCTAssertEqual(message.id, "m1")
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Hello")
        XCTAssertNotNil(message.createdAt)
        XCTAssertNil(message.attachments)
    }

    func testDecodeRichMessageJSON() throws {
        let json = """
        {
          "id": "42",
          "role": "assistant",
          "content": "**Bold**",
          "content_format": "markdown",
          "created_at": "2026-06-01T12:00:00Z",
          "attachments": [
            {
              "id": "7",
              "file_type": "voice",
              "file_name": "voice.m4a",
              "mime_type": "audio/mp4",
              "download_url": "/api/sessions/1/attachments/7/file",
              "transcription": "Hello"
            }
          ],
          "transcription": "Hello"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let message = try decoder.decode(KBMessage.self, from: json)

        XCTAssertEqual(message.contentFormat, .markdown)
        XCTAssertEqual(message.attachments?.count, 1)
        XCTAssertEqual(message.attachments?.first?.downloadURL, "/api/sessions/1/attachments/7/file")
        XCTAssertEqual(message.effectiveTranscription, "Hello")
    }

    func testVoiceOnlyDetection() {
        let voiceOnly = KBMessage(
            id: "v",
            role: .user,
            content: "🎤 Voice",
            createdAt: nil,
            attachments: [
                KBAttachment(
                    id: "1",
                    fileType: "voice",
                    fileName: nil,
                    fileSize: nil,
                    mimeType: "audio/mp4",
                    downloadURL: "/x",
                    transcription: "text"
                )
            ]
        )
        XCTAssertTrue(voiceOnly.isVoiceOnly)
    }
}

final class MessageContentRendererTests: XCTestCase {
    func testMarkdownBold() {
        let message = KBMessage(
            id: "1",
            role: .assistant,
            content: "**bold** text",
            createdAt: nil,
            contentFormat: .markdown
        )
        let attr = MessageContentRenderer.attributedText(for: message)
        XCTAssertFalse(String(attr.characters).isEmpty)
    }

    func testHTMLFallbackToPlain() {
        let message = KBMessage(
            id: "1",
            role: .assistant,
            content: "<b>Hi</b>",
            createdAt: nil,
            contentFormat: .html
        )
        let attr = MessageContentRenderer.attributedText(for: message)
        XCTAssertTrue(String(attr.characters).contains("Hi"))
    }
}
