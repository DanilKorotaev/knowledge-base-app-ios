import SwiftUI

struct ShareComposeView: View {
    @Bindable var viewModel: ShareComposeViewModel
    let onCancel: () -> Void
    let onFinished: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .loadingPayload:
                    ProgressView(L10n.string("share.loading"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failed, .ready, .working:
                    content
                        .overlay {
                            if viewModel.phase == .working {
                                ZStack {
                                    Color.black.opacity(0.15).ignoresSafeArea()
                                    ProgressView()
                                }
                            }
                        }
                }
            }
            .navigationTitle(L10n.string("share.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel"), action: onCancel)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
            .sheet(isPresented: $viewModel.showCreateSession) {
                NavigationStack {
                    Form {
                        TextField(L10n.string("session.title_field"), text: $viewModel.newSessionTitle)
                        Toggle(L10n.string("session.use_kb"), isOn: $viewModel.newSessionUseKnowledgeBase)
                    }
                    .navigationTitle(L10n.string("session.new_title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.string("common.cancel")) {
                                viewModel.showCreateSession = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.string("common.create")) {
                                Task { await viewModel.createSession() }
                            }
                            .disabled(viewModel.newSessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
    }

    private var content: some View {
        List {
            Section {
                TextField(L10n.string("share.composer_placeholder"), text: $viewModel.composerText, axis: .vertical)
                    .lineLimit(3 ... 8)

                if !viewModel.attachments.isEmpty {
                    ForEach(viewModel.attachments) { attachment in
                        Label(attachment.filename, systemImage: attachment.kind.systemImageName)
                            .font(.subheadline)
                    }
                }

                if viewModel.existingDraftAttachmentCount > 0 {
                    Text(
                        L10n.format(
                            "share.existing_draft_attachments_format",
                            viewModel.existingDraftAttachmentCount
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text(L10n.string("share.payload_section"))
            }

            Section {
                Button {
                    viewModel.showCreateSession = true
                } label: {
                    Label(L10n.string("main.new_session"), systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                }
                .disabled(viewModel.phase == .working || viewModel.phase == .loadingPayload)

                if viewModel.sessions.isEmpty {
                    Text(L10n.string("share.no_sessions"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.sessions) { session in
                        Button {
                            viewModel.selectSession(session)
                        } label: {
                            sessionRow(session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text(L10n.string("share.session_section"))
            }
        }
    }

    private func sessionRow(_ session: KBSession) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if viewModel.isPinned(session.id) {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(
                    L10n.format(
                        "main.messages_count_format",
                        session.messageCount,
                        session.kbModeLabel
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if viewModel.selectedSessionId == session.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if case .failed(let message) = viewModel.phase {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 10) {
                Button {
                    if viewModel.addToDraft() {
                        onFinished()
                    }
                } label: {
                    Text(L10n.string("share.add_to_draft"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canSubmit || viewModel.phase == .working)

                Button {
                    Task {
                        if await viewModel.send() {
                            onFinished()
                        }
                    }
                } label: {
                    Text(L10n.string("share.send"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canSubmit || viewModel.phase == .working)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.bar)
    }
}

private extension KBSession {
    var kbModeLabel: String {
        useKnowledgeBase
            ? L10n.string("session.kb_mode_on")
            : L10n.string("session.kb_mode_off")
    }
}
