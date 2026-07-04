import SwiftUI
import XCTest
@testable import KnowledgeBaseApp

final class VoiceRecordingSessionLogicTests: XCTestCase {
    func testAutoPauseOnlyWhenLockedAndRecording() {
        XCTAssertTrue(VoiceRecordingSessionLogic.shouldAutoPauseOnBackground(isLocked: true, isPaused: false))
        XCTAssertFalse(VoiceRecordingSessionLogic.shouldAutoPauseOnBackground(isLocked: true, isPaused: true))
        XCTAssertFalse(VoiceRecordingSessionLogic.shouldAutoPauseOnBackground(isLocked: false, isPaused: false))
    }

    func testManualPauseAndResumeGates() {
        XCTAssertTrue(VoiceRecordingSessionLogic.canManualPause(isLocked: true, isPaused: false))
        XCTAssertFalse(VoiceRecordingSessionLogic.canManualPause(isLocked: true, isPaused: true))

        XCTAssertTrue(VoiceRecordingSessionLogic.canResume(isLocked: true, isPaused: true))
        XCTAssertFalse(VoiceRecordingSessionLogic.canResume(isLocked: true, isPaused: false))
    }

    func testFinishAllowedInLockedMode() {
        XCTAssertTrue(VoiceRecordingSessionLogic.canFinish(isLocked: true))
        XCTAssertFalse(VoiceRecordingSessionLogic.canFinish(isLocked: false))
    }
}

@MainActor
final class VoiceRecordingViewModelPauseTests: XCTestCase {
    func testPauseAndResumeInLockedMode() async {
        let service = MockVoiceRecordingService()
        let viewModel = VoiceRecordingViewModel(recordingService: service, chatClient: StubChatAPIClient(store: InMemoryKBStore()))

        viewModel.handleDragChanged(.zero)
        try? await Task.sleep(for: .milliseconds(50))
        viewModel.handleDragChanged(CGSize(width: 0, height: -60))
        viewModel.handleDragEnded(CGSize(width: 0, height: -60))

        XCTAssertEqual(viewModel.phase, .locked)
        XCTAssertEqual(viewModel.lockedRecordingState, .recording)

        viewModel.pauseLockedSession()
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(viewModel.lockedRecordingState, .paused)
        XCTAssertEqual(service.pauseCallCount, 1)

        viewModel.resumeLockedSession()
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(viewModel.lockedRecordingState, .recording)
        XCTAssertEqual(service.resumeCallCount, 1)
    }

    func testBackgroundAutoPauseWhileLockedRecording() async {
        let service = MockVoiceRecordingService()
        let viewModel = VoiceRecordingViewModel(recordingService: service, chatClient: StubChatAPIClient(store: InMemoryKBStore()))

        viewModel.handleDragChanged(.zero)
        try? await Task.sleep(for: .milliseconds(50))
        viewModel.handleDragChanged(CGSize(width: 0, height: -60))
        viewModel.handleDragEnded(CGSize(width: 0, height: -60))

        viewModel.handleScenePhaseChange(.background)
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(viewModel.lockedRecordingState, .paused)
        XCTAssertEqual(service.pauseCallCount, 1)
    }

    func testBackgroundDoesNotPauseAlreadyPausedSession() async {
        let service = MockVoiceRecordingService()
        let viewModel = VoiceRecordingViewModel(recordingService: service, chatClient: StubChatAPIClient(store: InMemoryKBStore()))

        viewModel.handleDragChanged(.zero)
        try? await Task.sleep(for: .milliseconds(50))
        viewModel.handleDragChanged(CGSize(width: 0, height: -60))
        viewModel.handleDragEnded(CGSize(width: 0, height: -60))
        viewModel.pauseLockedSession()
        try? await Task.sleep(for: .milliseconds(50))

        viewModel.handleScenePhaseChange(.background)
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(service.pauseCallCount, 1)
    }
}

@MainActor
private final class MockVoiceRecordingService: VoiceRecordingServiceProtocol {
    var sessionPhase: VoiceRecordingSessionPhase = .idle
    var normalizedMeterLevel: Float = 0
    private(set) var pauseCallCount = 0
    private(set) var resumeCallCount = 0
    private var accumulated: TimeInterval = 0

    func elapsedDuration(at date: Date) -> TimeInterval {
        accumulated
    }

    func updateMetering() {}

    func startRecording() async throws {
        sessionPhase = .recording
    }

    func pauseRecording() async throws {
        pauseCallCount += 1
        sessionPhase = .paused
    }

    func resumeRecording() async throws {
        resumeCallCount += 1
        sessionPhase = .recording
    }

    func stopRecording() async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mock-voice-\(UUID().uuidString).m4a")
        try Data("mock".utf8).write(to: url)
        sessionPhase = .idle
        return url
    }

    func cancelRecording() async throws {
        sessionPhase = .idle
    }
}
