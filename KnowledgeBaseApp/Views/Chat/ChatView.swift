import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ChatView: View {
    @Environment(VoiceRoutingContext.self) private var voiceRouting
    @State private var viewModel: ChatViewModel
    @State private var scrollSpace = UUID()
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var showCamera = false

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
                            if let streaming = viewModel.streamingAssistantText, !streaming.isEmpty {
                                MessageBubbleView(
                                    message: KBMessage(
                                        id: "__kb_streaming__",
                                        role: .assistant,
                                        content: streaming,
                                        createdAt: Date()
                                    )
                                )
                                .id("__kb_streaming__")
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
                    .onChange(of: viewModel.streamingAssistantText) { _, _ in
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
        .onReceive(NotificationCenter.default.publisher(for: .kbSessionThreadDidChange)) { notification in
            guard let sid = notification.userInfo?[KBNotificationUserInfoKey.sessionId] as? String,
                  sid == viewModel.session.id else { return }
            Task { await viewModel.load() }
        }
        .onAppear {
            voiceRouting.activeSessionId = viewModel.session.id
            voiceRouting.useKnowledgeBase = viewModel.useKnowledgeBase
        }
        .onDisappear {
            voiceRouting.activeSessionId = nil
        }
        .onChange(of: viewModel.useKnowledgeBase) { _, newValue in
            voiceRouting.useKnowledgeBase = newValue
        }
        .onChange(of: photoPickerItem) { _, newItem in
            Task { await handlePhotoPicked(newItem) }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await viewModel.sendAttachment(
                        fileURL: url,
                        filename: url.lastPathComponent,
                        mimeType: url.kbPreferredMIMEType
                    )
                }
            case .failure(let error):
                viewModel.reportError(error.localizedDescription)
            }
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
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                onImage: { image in
                    showCamera = false
                    Task { await handleCameraImage(image) }
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Use knowledge base", isOn: $viewModel.useKnowledgeBase)
                .font(.subheadline)
            HStack(alignment: .bottom, spacing: 6) {
                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                }
                .disabled(viewModel.isSending)

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                    }
                    .disabled(viewModel.isSending)
                }

                Button {
                    showFileImporter = true
                } label: {
                    Image(systemName: "paperclip")
                        .font(.title3)
                }
                .disabled(viewModel.isSending)

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

    private func handlePhotoPicked(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        defer { photoPickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            viewModel.reportError("Could not read photo.")
            return
        }
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        do {
            try data.write(to: path)
            await viewModel.sendAttachment(
                fileURL: path,
                filename: "photo.jpg",
                mimeType: "image/jpeg"
            )
        } catch {
            viewModel.reportError(error.localizedDescription)
        }
    }

    private func handleCameraImage(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            viewModel.reportError("Could not encode photo.")
            return
        }
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        do {
            try data.write(to: path)
            await viewModel.sendAttachment(
                fileURL: path,
                filename: "camera.jpg",
                mimeType: "image/jpeg"
            )
        } catch {
            viewModel.reportError(error.localizedDescription)
        }
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
    .environment(VoiceRoutingContext())
}
