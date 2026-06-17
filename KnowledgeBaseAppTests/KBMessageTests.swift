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

    func testContentDuplicateTranscriptionHidesSecondBlock() {
        let tr = "Прошел я ТО, поменял масло. Пробег 39 586."
        let message = KBMessage(
            id: "v2",
            role: .user,
            content: tr,
            createdAt: nil,
            attachments: [
                KBAttachment(
                    id: "1",
                    fileType: "voice",
                    fileName: "voice.ogg",
                    fileSize: 100,
                    mimeType: "audio/ogg",
                    downloadURL: "/x",
                    transcription: tr
                )
            ],
            transcription: tr
        )
        XCTAssertTrue(message.contentDuplicatesVoiceTranscription)
        XCTAssertTrue(message.isVoiceOnly)
        XCTAssertNil(message.bubbleTextContent)
    }

    func testCompositePhotoVoiceShowsTranscriptionOnce() {
        let tr = "Текст расшифровки голосового сообщения."
        let message = KBMessage(
            id: "cv",
            role: .user,
            content: tr,
            createdAt: nil,
            attachments: [
                KBAttachment(
                    id: "p",
                    fileType: "photo",
                    fileName: "a.jpg",
                    fileSize: 100,
                    mimeType: "image/jpeg",
                    downloadURL: "/p",
                    transcription: nil
                ),
                KBAttachment(
                    id: "v",
                    fileType: "voice",
                    fileName: "v.m4a",
                    fileSize: 100,
                    mimeType: "audio/mp4",
                    downloadURL: "/v",
                    transcription: tr
                )
            ],
            transcription: tr
        )
        XCTAssertTrue(message.isCompositeAttachmentMessage)
        XCTAssertFalse(message.isSingleVoiceOnlyMessage)
        XCTAssertNil(message.bubbleTextContent)
    }

    func testCompositePhotoVoiceKeepsExtraText() {
        let tr = "Голосовая часть."
        let message = KBMessage(
            id: "cv2",
            role: .user,
            content: "\(tr)\n\nПодпись к фото.",
            createdAt: nil,
            attachments: [
                KBAttachment(
                    id: "p",
                    fileType: "photo",
                    fileName: "a.jpg",
                    fileSize: 100,
                    mimeType: "image/jpeg",
                    downloadURL: "/p",
                    transcription: nil
                ),
                KBAttachment(
                    id: "v",
                    fileType: "voice",
                    fileName: "v.m4a",
                    fileSize: 100,
                    mimeType: "audio/mp4",
                    downloadURL: "/v",
                    transcription: tr
                )
            ]
        )
        XCTAssertEqual(message.bubbleTextContent, "Подпись к фото.")
    }

    func testPlainTextPreservesNewlines() {
        let message = KBMessage(
            id: "plain",
            role: .user,
            content: "Line one\nLine two",
            createdAt: nil,
            contentFormat: .plain
        )
        XCTAssertEqual(message.bubbleTextContent, "Line one\nLine two")
    }

    func testComposedVoiceTranscription_joinsMultipleVoices() {
        let message = KBMessage(
            id: "mv",
            role: .user,
            content: "Two clips",
            createdAt: nil,
            attachments: [
                KBAttachment(
                    id: "v1",
                    fileType: "voice",
                    fileName: "a.m4a",
                    fileSize: 10,
                    mimeType: "audio/mp4",
                    downloadURL: "/a",
                    transcription: "First"
                ),
                KBAttachment(
                    id: "v2",
                    fileType: "voice",
                    fileName: "b.m4a",
                    fileSize: 10,
                    mimeType: "audio/mp4",
                    downloadURL: "/b",
                    transcription: "Second"
                )
            ]
        )

        XCTAssertEqual(message.composedVoiceTranscription, "First\n\nSecond")
        XCTAssertTrue(message.isCompositeAttachmentMessage)
    }

    func testContentDuplicateTranscription_prefixOverlap() {
        let longer = String(repeating: "x", count: 100)
        let shorter = String(repeating: "x", count: 86)
        let message = KBMessage(
            id: "prefix",
            role: .user,
            content: shorter,
            createdAt: nil,
            attachments: [
                KBAttachment(
                    id: "v",
                    fileType: "voice",
                    fileName: "v.m4a",
                    fileSize: 1,
                    mimeType: "audio/mp4",
                    downloadURL: "/v",
                    transcription: longer
                )
            ],
            transcription: longer
        )

        XCTAssertTrue(message.contentDuplicatesVoiceTranscription)
    }

    func testVoiceOnly_voiceNoteMarker() {
        let message = KBMessage(
            id: "vn",
            role: .user,
            content: "voice note",
            createdAt: nil,
            attachments: [
                KBAttachment(
                    id: "v",
                    fileType: "voice",
                    fileName: "v.m4a",
                    fileSize: 1,
                    mimeType: "audio/mp4",
                    downloadURL: "/v",
                    transcription: "spoken"
                )
            ]
        )

        XCTAssertTrue(message.isVoiceOnly)
    }

    func testResolvedContentFormat_defaultsByRole() {
        let assistant = KBMessage(id: "a", role: .assistant, content: "hi", createdAt: nil)
        let user = KBMessage(id: "u", role: .user, content: "hi", createdAt: nil)

        XCTAssertEqual(assistant.resolvedContentFormat, .markdown)
        XCTAssertEqual(user.resolvedContentFormat, .plain)
    }

    func testImageAndVoiceAttachmentFilters() {
        let message = KBMessage(
            id: "mix",
            role: .user,
            content: "caption",
            createdAt: nil,
            attachments: [
                KBAttachment(
                    id: "p",
                    fileType: "photo",
                    fileName: "p.jpg",
                    fileSize: 1,
                    mimeType: "image/jpeg",
                    downloadURL: "/p",
                    transcription: nil
                ),
                KBAttachment(
                    id: "v",
                    fileType: "voice",
                    fileName: "v.m4a",
                    fileSize: 1,
                    mimeType: "audio/mp4",
                    downloadURL: "/v",
                    transcription: "voice text"
                )
            ]
        )

        XCTAssertEqual(message.imageAttachments.count, 1)
        XCTAssertEqual(message.voiceAttachments.count, 1)
        XCTAssertEqual(message.effectiveTranscription, "voice text")
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

    func testStripsTerminalEscapeSequences() {
        let content = "Done.\n\u{1B}[?25h"
        let attr = MessageContentRenderer.attributedText(from: content, format: .markdown)
        XCTAssertEqual(String(attr.characters), "Done.")
        XCTAssertFalse(String(attr.characters).contains("[?25h"))
    }

    func testMarkdownHeaderUsesFullSyntax() {
        let content = "### Блоки\n\n**жирный**"
        let attr = MessageContentRenderer.parseMarkdown(content)
        let plain = String(attr.characters)
        XCTAssertFalse(plain.contains("###"), "Header markers should be parsed, not shown literally")
        XCTAssertTrue(plain.contains("Блоки"))
        XCTAssertTrue(plain.contains("жирный"))
    }

    func testMarkdownThematicBreak() {
        XCTAssertTrue(MarkdownLineParser.isThematicBreak("---"))
        XCTAssertTrue(MarkdownLineParser.isThematicBreak("- - -"))
        XCTAssertTrue(MarkdownLineParser.isThematicBreak("***"))
        XCTAssertTrue(MarkdownLineParser.isThematicBreak("___"))
        XCTAssertFalse(MarkdownLineParser.isThematicBreak("--"))
        XCTAssertFalse(MarkdownLineParser.isThematicBreak("--- still text"))
    }

    func testMarkdownSegmentParserListAndCode() {
        let md = """
        Intro line

        - first
        - second

        ```swift
        let x = 1
        ```

        > quote one
        > quote two
        """
        let segments = MarkdownSegmentParser.segments(from: md)
        XCTAssertTrue(segments.contains { if case .paragraph(let s) = $0 { return s == "Intro line" } else { return false } })
        XCTAssertTrue(segments.contains { if case .list(let items) = $0 { return items.count == 2 && items[0].text == "first" } else { return false } })
        XCTAssertTrue(segments.contains { if case .codeBlock(let lang, let code) = $0 { return lang == "swift" && code.contains("let x") } else { return false } })
        XCTAssertTrue(segments.contains { if case .blockquote(let lines) = $0 { return lines == ["quote one", "quote two"] } else { return false } })
    }

    func testMarkdownNestedListIndent() {
        let item = MarkdownLineParser.parseListItem("  - nested item")
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.indentLevel, 1)
        XCTAssertEqual(item?.text, "nested item")
    }

    func testMarkdownTableParser() {
        let md = """
        Intro

        | A | B |
        |---|---|
        | 1 | 2 |

        Outro
        """
        let blocks = MarkdownBlockParser.blocks(from: md)
        XCTAssertEqual(blocks.count, 3)
        if case .text(let intro) = blocks[0] {
            XCTAssertTrue(intro.contains("Intro"))
        } else {
            XCTFail("expected text block")
        }
        if case .table(let header, let rows) = blocks[1] {
            XCTAssertEqual(header, ["A", "B"])
            XCTAssertEqual(rows, [["1", "2"]])
        } else {
            XCTFail("expected table block")
        }
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
