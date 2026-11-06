@testable import KnowledgeBaseApp
import XCTest

final class VoicePipelineErrorMessageTests: XCTestCase {
    override func tearDown() {
        AppLanguageStore.shared.resetForTesting()
        super.tearDown()
    }

    func testGatewayUsesHumanTranscriptionTimeoutCopy() {
        AppLanguageStore.shared.setOverride(.english)
        let message = VoicePipelineErrorMessage.forTranscription(
            KnowledgeBaseAPIError.invalidResponse(statusCode: 504, apiMessage: "VPN check on server…")
        )
        XCTAssertEqual(message, L10n.string("error.transcription_timeout"))
        XCTAssertFalse(message.contains("VPN"))
        XCTAssertFalse(message.contains("504"))
    }

    func testGatewayRussianCopy() {
        AppLanguageStore.shared.setOverride(.russian)
        let message = VoicePipelineErrorMessage.forTranscription(
            KnowledgeBaseAPIError.invalidResponse(statusCode: 502, apiMessage: nil)
        )
        XCTAssertEqual(message, L10n.string("error.transcription_timeout"))
    }

    func testURLErrorTimedOutUsesTranscriptionTimeout() {
        AppLanguageStore.shared.setOverride(.english)
        let message = VoicePipelineErrorMessage.forTranscription(URLError(.timedOut))
        XCTAssertEqual(message, L10n.string("error.transcription_timeout"))
        XCTAssertNotEqual(message, "Timed out.")
    }

    func testURLErrorNotConnectedIsShort() {
        AppLanguageStore.shared.setOverride(.russian)
        let message = VoicePipelineErrorMessage.forTranscription(URLError(.notConnectedToInternet))
        XCTAssertEqual(message, "Нет подключения к интернету.")
        XCTAssertFalse(message.contains("Повторить"))
        XCTAssertFalse(message.contains("VPN"))
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
