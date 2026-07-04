import SwiftUI

struct PostRecordingReviewSheet: View {
    @Bindable var viewModel: VoiceRecordingViewModel
    let sessions: [KBSession]
    @Bindable var voiceRouting: VoiceRoutingContext

    private var resolvedSessionId: String? {
        voiceRouting.resolveVoiceTargetSessionId(in: sessions)
    }

    private var resolvedSessionTitle: String? {
        voiceRouting.resolveVoiceTargetSession(in: sessions)?.title
    }

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.isTranscribing {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Распознаём речь…")
                        }
                    }
                }

                if let failure = viewModel.transcriptionFailureMessage {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Голосовое не распознано")
                                .font(.subheadline.weight(.semibold))
                            Text(failure)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Повторить") {
                                Task { await viewModel.retryTranscription() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isTranscribing)
                        }
                    }
                }

                Section {
                    TextField(
                        "Текст сообщения",
                        text: $viewModel.transcriptionDraft,
                        axis: .vertical
                    )
                    .lineLimit(4 ... 12)
                    .disabled(viewModel.isTranscribing)
                } header: {
                    Text("Проверка")
                } footer: {
                    if let title = resolvedSessionTitle {
                        Text("Отправится в «\(title)». Можно отредактировать текст вручную.")
                    } else if sessions.isEmpty {
                        Text("Сначала создайте чат, затем отправьте сообщение.")
                    } else {
                        Text("Отредактируйте текст и нажмите «Отправить в чат».")
                    }
                }
            }
            .navigationTitle("Голосовое")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.transcribeRecordedAudioIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Удалить") {
                        viewModel.dismissPostRecordReview()
                    }
                    .disabled(viewModel.isSendingVoice)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSendingVoice {
                        ProgressView()
                    } else {
                        Button("Отправить в чат") {
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
