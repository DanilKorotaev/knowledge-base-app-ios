import XCTest
@testable import KnowledgeBaseApp

final class VoicePipelineErrorMessageTests: XCTestCase {
    func testTimeoutUsesHumanCopy() {
        let message = VoicePipelineErrorMessage.forTranscription(URLError(.timedOut))
        XCTAssertFalse(message.localizedCaseInsensitiveContains("alamofire"))
        XCTAssertNotEqual(message, "Timed out.")
        XCTAssertFalse(message.isEmpty)
    }

    func testGatewayUsesTranscriptionTimeoutCopy() {
        let err = KnowledgeBaseAPIError.invalidResponse(statusCode: 502, apiMessage: "VPN check on server…")
        let message = VoicePipelineErrorMessage.forTranscription(err)
        XCTAssertFalse(message.contains("VPN"))
        XCTAssertEqual(message, L10n.string("error.transcription_timeout"))
    }

    func testTransientDetection() {
        XCTAssertTrue(VoicePipelineErrorMessage.isTransientTranscriptionFailure(URLError(.timedOut)))
        XCTAssertTrue(
            VoicePipelineErrorMessage.isTransientTranscriptionFailure(
                KnowledgeBaseAPIError.invalidResponse(statusCode: 504, apiMessage: nil)
            )
        )
        XCTAssertFalse(
            VoicePipelineErrorMessage.isTransientTranscriptionFailure(
                KnowledgeBaseAPIError.invalidResponse(statusCode: 422, apiMessage: nil)
            )
        )
    }
}
