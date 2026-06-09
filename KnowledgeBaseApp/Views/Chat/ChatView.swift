import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ChatView: View {
    @Environment(VoiceRoutingContext.self) private var voiceRouting
    @Environment(VoiceRecordingViewModel.self) private var voiceViewModel
    @State private var viewModel: ChatViewModel
    @State private var isChatScrollReady = false
    @State private var userHasScrolled = false
    @State private var suppressPaginationUntil: Date = .distantPast
    @State private var latestScrollSample: ScrollPaginationSample?
    @State private var bottomScrollID = "kb-chat-bottom"
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var showCamera = false
    private let attachmentLoader: KBAttachmentLoaderProtocol?

    /// Pause auto-load after prepend while layout settles (prevents cascade from geometry/onAppear).
    private static let paginationSettleDelay: TimeInterval = 0.85

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
                            if viewModel.hasMoreOlder {
                                Color.clear
                                    .frame(height: 1)
                                    .onAppear { topLoadSentinelDidAppear() }
                            }

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
                                .onAppear {
                                    oldestMessageDidAppear(message.id)
                                }
                            }
                            if viewModel.assistantReplyPhase.showsPlaceholder {
                                assistantReplyPhaseView
                            }
                            Color.clear
                                .frame(height: 1)
                                .id(bottomScrollID)
                        }
                        .padding()
                        .scrollTargetLayout()
                    }
                    .defaultScrollAnchor(.bottom)
                    .onScrollGeometryChange(for: ScrollPaginationSample.self) { geometry in
                        ScrollPaginationSample(geometry: geometry)
                    } action: { _, current in
                        latestScrollSample = current
                        ChatPaginationLogger.scrollSample(current)
                    }
                    .onScrollPhaseChange { _, newPhase, _ in
                        if newPhase == .interacting {
                            userHasScrolled = true
                        }
                    }
                    .onChange(of: viewModel.isLoadingOlder) { wasLoadingOlder, isLoadingOlder in
                        guard wasLoadingOlder, !isLoadingOlder else { return }
                        suppressPaginationUntil = Date().addingTimeInterval(Self.paginationSettleDelay)
                        ChatPaginationLogger.paginationSuppressed(untilSeconds: Self.paginationSettleDelay)
                        schedulePostSettlePaginationCheck()
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
            ChatPaginationLogger.sessionTaskStarted(sessionId: viewModel.session.id)
            resetChatScrollState()
            await viewModel.load()
            guard !viewModel.messages.isEmpty else { return }
            armChatScrollAfterInitialLoad()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kbSessionThreadDidChange)) { notification in
            guard let sid = notification.userInfo?[KBNotificationUserInfoKey.sessionId] as? String,
                  sid == viewModel.session.id else { return }
            Task {
                await viewModel.waitForStreamRevealAnimation()
                await viewModel.reloadLatestWindow()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AssistantReplyPhaseNotification.name)) { notification in
            guard let parsed = AssistantReplyPhaseNotification.parse(notification),
                  parsed.sessionId == viewModel.session.id else { return }
            viewModel.applyExternalAssistantPhase(parsed.phase)
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

    @ViewBuilder
    private var assistantReplyPhaseView: some View {
        switch viewModel.assistantReplyPhase {
        case .idle:
            EmptyView()
        case .waiting:
            AssistantPendingBubbleView()
                .id("__kb_assistant_waiting__")
        case .streaming(let text) where text.isEmpty:
            AssistantPendingBubbleView()
                .id("__kb_assistant_streaming_empty__")
        case .streaming(let text), .finalizing(let text):
            StreamingAssistantBubbleView(
                text: text,
                showsTypingIndicator: viewModel.assistantReplyPhase.showsTypingIndicator,
                isFinishing: {
                    if case .finalizing = viewModel.assistantReplyPhase { return true }
                    return false
                }(),
                onRevealedGrowth: { viewModel.scrollIntent = .scrollToBottom },
                onRevealComplete: { viewModel.completeStreamRevealAnimation() }
            )
            .id("__kb_assistant_streaming__")
        }
    }

    private func resetChatScrollState() {
        isChatScrollReady = false
        userHasScrolled = false
        suppressPaginationUntil = .distantPast
        ChatPaginationLogger.scrollStateReset()
    }

    private func armChatScrollAfterInitialLoad() {
        isChatScrollReady = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isChatScrollReady = true
            ChatPaginationLogger.scrollArmed(afterSeconds: 0.4)
        }
    }

    private func schedulePostSettlePaginationCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.paginationSettleDelay + 0.05) {
            guard isChatScrollReady, userHasScrolled else { return }
            guard Date() >= suppressPaginationUntil else { return }
            guard latestScrollSample?.isNearOldestEdge == true else { return }
            requestOlderMessagesIfNeeded(source: "post-settle")
        }
    }

    private func topLoadSentinelDidAppear() {
        guard isChatScrollReady, userHasScrolled else { return }
        requestOlderMessagesIfNeeded(source: "top-sentinel")
    }

    private func oldestMessageDidAppear(_ messageId: String) {
        let firstId = viewModel.messages.first?.id
        ChatPaginationLogger.oldestMessageAppeared(messageId: messageId, firstMessageId: firstId)
        guard isChatScrollReady else {
            ChatPaginationLogger.requestBlocked("isChatScrollReady=false", context: "onAppear")
            return
        }
        guard userHasScrolled else {
            ChatPaginationLogger.requestBlocked("userHasScrolled=false", context: "onAppear")
            return
        }
        guard messageId == firstId else { return }
        requestOlderMessagesIfNeeded(source: "onAppear")
    }

    private func requestOlderMessagesIfNeeded(source: String) {
        if Date() < suppressPaginationUntil {
            ChatPaginationLogger.requestBlocked("pagination settle window", context: source)
            return
        }
        if !viewModel.hasMoreOlder {
            ChatPaginationLogger.requestBlocked("hasMoreOlder=false", context: source)
            return
        }
        if viewModel.isLoadingOlder {
            ChatPaginationLogger.requestBlocked("isLoadingOlder=true", context: source)
            return
        }
        if viewModel.isLoading {
            ChatPaginationLogger.requestBlocked("isLoading=true", context: source)
            return
        }
        ChatPaginationLogger.requestStarted(
            source: source,
            anchorId: viewModel.messages.first?.id
        )
        Task { await viewModel.loadOlder() }
    }

    private func applyScrollIntent(_ intent: ChatScrollIntent, proxy: ScrollViewProxy) {
        guard intent != .none else { return }
        switch intent {
        case .none:
            break
        case .scrollToBottom:
            proxy.scrollTo(bottomScrollID, anchor: .bottom)
        case .preserve(let messageId):
            // Restore anchor after prepend once suppress window is active (avoids cascade + jump).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                proxy.scrollTo(messageId, anchor: .top)
            }
        }
        ChatPaginationLogger.scrollIntent(intent)
        viewModel.acknowledgeScrollIntent()
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
