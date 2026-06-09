import XCTest
@testable import KnowledgeBaseApp

final class ChatComposerDraftTests: XCTestCase {
    func testCanSendWhenTextAttachmentsOrVoicePresent() {
        var draft = ChatComposerDraft()
        XCTAssertFalse(draft.canSend)

        draft.text = "  hi  "
        XCTAssertTrue(draft.canSend)

        draft = ChatComposerDraft()
        draft.attachments = [
            PendingAttachment(localURL: URL(fileURLWithPath: "/tmp/a.jpg"), kind: .image, filename: "a.jpg", mimeType: "image/jpeg")
        ]
        XCTAssertTrue(draft.canSend)
    }

    func testAppendTranscriptionPreservesExistingText() {
        var draft = ChatComposerDraft()
        draft.text = "First line."
        draft.appendTranscription("Second part.")
        XCTAssertEqual(draft.text, "First line. Second part.")
    }

    func testSendPlanner_textOnly() {
        var draft = ChatComposerDraft()
        draft.text = "Hello"
        if case .textOnly(let text) = ChatComposerSendPlanner.route(for: draft) {
            XCTAssertEqual(text, "Hello")
        } else {
            XCTFail("Expected textOnly")
        }
    }

    func testSendPlanner_rejectsMultipleAttachments() {
        var draft = ChatComposerDraft()
        draft.attachments = [
            PendingAttachment(localURL: URL(fileURLWithPath: "/tmp/1"), kind: .file, filename: "1", mimeType: "text/plain"),
            PendingAttachment(localURL: URL(fileURLWithPath: "/tmp/2"), kind: .file, filename: "2", mimeType: "text/plain"),
        ]
        if case .compose = ChatComposerSendPlanner.route(for: draft) {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected compose")
        }
    }

    func testSendPlanner_textWithAttachmentUsesCompose() {
        var draft = ChatComposerDraft()
        draft.text = "Caption"
        draft.attachments = [
            PendingAttachment(localURL: URL(fileURLWithPath: "/tmp/1"), kind: .image, filename: "1.jpg", mimeType: "image/jpeg"),
        ]
        if case .compose = ChatComposerSendPlanner.route(for: draft) {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected compose")
        }
    }

    func testSendPlanner_singleVoiceUsesDraftText() {
        var draft = ChatComposerDraft()
        draft.voiceClips = [
            PendingVoiceClip(audioURL: URL(fileURLWithPath: "/tmp/v.m4a"), transcriptionSegment: "voice text")
        ]
        draft.text = "Edited caption"
        if case .singleVoice(_, let text) = ChatComposerSendPlanner.route(for: draft) {
            XCTAssertEqual(text, "Edited caption")
        } else {
            XCTFail("Expected singleVoice")
        }
    }
}
