import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ChatView: View {
    @Environment(VoiceRoutingContext.self) private var voiceRouting
    @Environment(VoiceRecordingViewModel.self) private var voiceViewModel
    @State private var viewModel: ChatViewModel
    @State private var bottomScrollID = "kb-chat-bottom"
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var showCamera = false
    private let attachmentLoader: KBAttachmentLoaderProtocol?

    init(
        session: KBSession,
        chatClient: ChatAPIClientProtocol,
        attachmentLoader: KBAttachmentLoaderProtocol? = nil
    ) {
        _viewModel = State(
            initialValue: ChatViewModel(session: session, client: chatClient)
        )
        self.attachmentLoader = attachmentLoader
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                ProgressView("Loading messages…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if viewModel.isLoadingOlder {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            } else if viewModel.hasMoreOlder {
                                Color.clear
                                    .frame(height: 1)
                                    .onAppear {
                                        Task { await viewModel.loadOlder() }
                                    }
                            }

                            ForEach(viewModel.messages) { message in
                                RichMessageBubbleView(
                                    message: message,
                                    attachmentLoader: attachmentLoader
                                )
                                .id(message.id)
                            }
                            if let streaming = viewModel.streamingAssistantText, !streaming.isEmpty {
                                RichMessageBubbleView(
                                    message: KBMessage(
                                        id: "__kb_streaming__",
                                        role: .assistant,
                                        content: streaming,
                                        createdAt: Date(),
                                        contentFormat: .markdown
                                    ),
                                    attachmentLoader: attachmentLoader
                                )
                                .id("__kb_streaming__")
                            }
                            Color.clear
                                .frame(height: 1)
                                .id(bottomScrollID)
                        }
                        .padding()
                    }
                    .defaultScrollAnchor(.bottom)
                    .onAppear {
                        guard !viewModel.messages.isEmpty, !viewModel.isLoading else { return }
                        scrollToBottom(proxy: proxy, delayed: true)
                    }
                    .onChange(of: viewModel.scrollAnchorMessageId) { _, anchor in
                        guard let anchor else { return }
                        DispatchQueue.main.async {
                            proxy.scrollTo(anchor, anchor: .top)
                            viewModel.scrollAnchorMessageId = nil
                        }
                    }
                    .onChange(of: viewModel.messages.count) { oldCount, newCount in
                        guard viewModel.scrollAnchorMessageId == nil else { return }
                        guard newCount > oldCount, !viewModel.isLoadingOlder else { return }
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.streamingAssistantText) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.isLoading) { _, loading in
                        guard !loading, !viewModel.messages.isEmpty else { return }
                        scrollToBottom(proxy: proxy, delayed: true)
                    }
                }
            }

            inputBar
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if voiceViewModel.phase != .idle {
                MicRecordControl(viewModel: voiceViewModel)
                    .background(.bar)
            }
        }
        .navigationTitle(viewModel.session.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kbSessionThreadDidChange)) { notification in
            guard let sid = notification.userInfo?[KBNotificationUserInfoKey.sessionId] as? String,
                  sid == viewModel.session.id else { return }
            Task { await viewModel.reloadLatestWindow() }
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

    private func scrollToBottom(proxy: ScrollViewProxy, delayed: Bool = false) {
        let scroll = {
            proxy.scrollTo(bottomScrollID, anchor: .bottom)
        }
        if delayed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: scroll)
        } else {
            DispatchQueue.main.async(execute: scroll)
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

                ChatMicButton(viewModel: voiceViewModel)
                    .opacity(voiceViewModel.phase == .idle ? 1 : 0.35)

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
        RichMessageBubbleView(message: message)
    }
}

#Preview {
    NavigationStack {
        ChatView(
            session: KBSession(id: "demo-session", title: "Demo", messageCount: 0, updatedAt: nil),
            chatClient: StubChatAPIClient(store: InMemoryKBStore()),
            attachmentLoader: StubAttachmentLoader()
        )
    }
    .environment(VoiceRoutingContext())
    .environment(VoiceRecordingViewModel(chatClient: StubChatAPIClient(store: InMemoryKBStore())))
}
