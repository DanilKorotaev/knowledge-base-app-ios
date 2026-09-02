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
                case .failed(let message):
                    content
                        .safeAreaInset(edge: .bottom) {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(.ultraThinMaterial)
                        }
                case .ready, .working:
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
                ToolbarItem(placement: .primaryAction) {
                    Button(L10n.string("main.new_session")) {
                        viewModel.showCreateSession = true
                    }
                    .disabled(viewModel.phase == .working || viewModel.phase == .loadingPayload)
                }
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
                        Label(attachment.filename, systemImage: attachment.kind == .image ? "photo" : "doc")
                            .font(.subheadline)
                    }
                }
            } header: {
                Text(L10n.string("share.payload_section"))
            }

            Section {
                if viewModel.sessions.isEmpty {
                    Text(L10n.string("share.no_sessions"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.sessions) { session in
                        Button {
                            viewModel.selectSession(session)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.title)
                                        .foregroundStyle(.primary)
                                    Text(session.kbModeLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if viewModel.selectedSessionId == session.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text(L10n.string("share.session_section"))
            }

            Section {
                Button(L10n.string("share.add_to_draft")) {
                    if viewModel.addToDraft() {
                        onFinished()
                    }
                }
                .disabled(!viewModel.canSubmit || viewModel.phase == .working)

                Button(L10n.string("share.send")) {
                    Task {
                        if await viewModel.send() {
                            onFinished()
                        }
                    }
                }
                .disabled(!viewModel.canSubmit || viewModel.phase == .working)
            }
        }
    }
}

private extension KBSession {
    var kbModeLabel: String {
        useKnowledgeBase
            ? L10n.string("session.kb_mode_on")
            : L10n.string("session.kb_mode_off")
    }
}
