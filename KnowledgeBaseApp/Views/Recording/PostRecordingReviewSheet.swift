import SwiftUI

struct PostRecordingReviewSheet: View {
    @Bindable var viewModel: VoiceRecordingViewModel
    let sessions: [KBSession]
    @Bindable var voiceRouting: VoiceRoutingContext

    private var resolvedSessionId: String? {
        voiceRouting.activeSessionId ?? sessions.first?.id
    }

    private var resolvedSessionTitle: String? {
        if let id = resolvedSessionId {
            return sessions.first(where: { $0.id == id })?.title
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.isTranscribing {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Transcribing…")
                        }
                    }
                }

                Section {
                    TextField(
                        "Transcription",
                        text: $viewModel.transcriptionDraft,
                        axis: .vertical
                    )
                    .lineLimit(4 ... 12)
                    .disabled(viewModel.isTranscribing)
                } header: {
                    Text("Review")
                } footer: {
                    if let title = resolvedSessionTitle {
                        Text("Will send to “\(title)”. Edit the text, then tap Send to chat.")
                    } else if sessions.isEmpty {
                        Text("Create a session first, then send your message.")
                    } else {
                        Text("Edit the text, then tap Send to chat.")
                    }
                }
            }
            .navigationTitle("Voice note")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.transcribeRecordedAudioIfNeeded()
            }
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
                        Button("Send to chat") {
                            viewModel.confirmPostRecordUpload(
                                sessionId: resolvedSessionId,
                                useKnowledgeBase: voiceRouting.useKnowledgeBase
                            )
                        }
                        .disabled(!viewModel.canSendTranscription || resolvedSessionId == nil)
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
