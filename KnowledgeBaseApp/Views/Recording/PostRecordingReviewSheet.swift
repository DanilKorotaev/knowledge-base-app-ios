import SwiftUI

struct PostRecordingReviewSheet: View {
    @Bindable var viewModel: VoiceRecordingViewModel
    let sessions: [KBSession]
    @Bindable var voiceRouting: VoiceRoutingContext

    private var resolvedSessionId: String? {
        voiceRouting.activeSessionId ?? sessions.first?.id
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Transcription will appear here after Whisper (KB App API)",
                        text: $viewModel.transcriptionDraft,
                        axis: .vertical
                    )
                    .lineLimit(4 ... 12)
                } header: {
                    Text("Review")
                } footer: {
                    Text("Edit text before sending. The backend will replace this with Whisper output later.")
                }
            }
            .navigationTitle("Voice note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        viewModel.dismissPostRecordReview()
                    }
                    .disabled(viewModel.isSendingVoice)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSendingVoice {
                        ProgressView()
                    } else {
                        Button("Send") {
                            viewModel.confirmPostRecordUpload(
                                sessionId: resolvedSessionId,
                                useKnowledgeBase: voiceRouting.useKnowledgeBase
                            )
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    PostRecordingReviewSheet(
        viewModel: VoiceRecordingViewModel(chatClient: StubChatAPIClient(store: InMemoryKBStore())),
        sessions: [KBSession(id: "demo-session", title: "Demo", messageCount: 0, updatedAt: nil)],
        voiceRouting: VoiceRoutingContext()
    )
}
