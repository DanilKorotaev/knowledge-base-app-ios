import SwiftUI

struct ChatView: View {
    @State private var viewModel: ChatViewModel
    @State private var scrollSpace = UUID()

    init(session: KBSession, chatClient: ChatAPIClientProtocol) {
        _viewModel = State(
            initialValue: ChatViewModel(session: session, client: chatClient)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                ProgressView("Loading messages…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                            Color.clear
                                .frame(height: 1)
                                .id(scrollSpace)
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(scrollSpace, anchor: .bottom)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(scrollSpace, anchor: .bottom)
                    }
                }
            }

            inputBar
        }
        .navigationTitle(viewModel.session.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .alert("Chat", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Use knowledge base", isOn: $viewModel.useKnowledgeBase)
                .font(.subheadline)
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message", text: $viewModel.draft, axis: .vertical)
                    .lineLimit(1 ... 6)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                }
                .disabled(
                    viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.isSending
                )
            }
        }
        .padding()
        .background(.bar)
    }
}

struct MessageBubbleView: View {
    let message: KBMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 56)
            }
            Text(message.content)
                .font(.body)
                .padding(12)
                .background(
                    message.role == .user
                        ? Color.accentColor.opacity(0.22)
                        : Color.secondary.opacity(0.14)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            if message.role == .assistant {
                Spacer(minLength: 56)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
}

#Preview {
    NavigationStack {
        ChatView(
            session: KBSession(id: "demo-session", title: "Demo", messageCount: 0, updatedAt: nil),
            chatClient: StubChatAPIClient(store: InMemoryKBStore())
        )
    }
}
