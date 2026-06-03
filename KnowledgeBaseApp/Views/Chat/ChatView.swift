import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ChatView: View {
    @Environment(VoiceRoutingContext.self) private var voiceRouting
    @Environment(VoiceRecordingViewModel.self) private var voiceViewModel
    @State private var viewModel: ChatViewModel
    @State private var hasPinnedToBottom = false
    @State private var bottomScrollID = "kb-chat-bottom"
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var showCamera = false
    private let attachmentLoader: KBAttachmentLoaderProtocol?
    private let olderLoadTopThreshold: CGFloat = 80

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
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if viewModel.isLoadingOlder {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding(.vertical, 8)
                                    Spacer()
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
                    .onScrollGeometryChange(for: Bool.self) { geometry in
                        Self.isNearOldestEdge(geometry, threshold: olderLoadTopThreshold)
                    } action: { wasNearTop, isNearTop in
                        guard hasPinnedToBottom, isNearTop, !wasNearTop else { return }
                        Task { await viewModel.loadOlder() }
                    }
                    .onChange(of: viewModel.scrollIntent) { _, intent in
                        applyScrollIntent(intent, proxy: proxy)
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
        .task(id: viewModel.session.id) {
            hasPinnedToBottom = false
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

    private func applyScrollIntent(_ intent: ChatScrollIntent, proxy: ScrollViewProxy) {
        guard intent != .none else { return }
        let apply = {
            switch intent {
            case .none:
                break
            case .scrollToBottom:
                proxy.scrollTo(bottomScrollID, anchor: .bottom)
                hasPinnedToBottom = true
            case .preserve(let messageId):
                proxy.scrollTo(messageId, anchor: .top)
            }
            viewModel.acknowledgeScrollIntent()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: apply)
    }

    /// True when the scroll offset is at the oldest edge (user reached the top of the thread).
    private static func isNearOldestEdge(_ geometry: ScrollGeometry, threshold: CGFloat) -> Bool {
        let contentHeight = geometry.contentSize.height
        let viewportHeight = geometry.visibleRect.height
        guard contentHeight > viewportHeight + 8 else { return false }
        return geometry.contentOffset.y + geometry.contentInsets.top <= threshold
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
