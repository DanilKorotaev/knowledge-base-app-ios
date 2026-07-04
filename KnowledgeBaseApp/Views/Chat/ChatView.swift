import SwiftUI
import UIKit

struct ChatView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(VoiceRoutingContext.self) private var voiceRouting
    @Environment(VoiceRecordingViewModel.self) private var voiceViewModel
    @State private var viewModel: ChatViewModel
    @State private var isChatScrollReady = false
    @State private var userHasScrolled = false
    @State private var suppressPaginationUntil: Date = .distantPast
    @State private var latestScrollSample: ScrollPaginationSample?
    @State private var bottomScrollID = "kb-chat-bottom"
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
            if viewModel.syncStatus.showsBanner {
                SyncStatusBannerView(status: viewModel.syncStatus)
            }

            if viewModel.isLoading && viewModel.messages.isEmpty {
                ProgressView("chat.loading_messages")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
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
                                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                                    RichMessageBubbleView(
                                        message: message,
                                        attachmentLoader: attachmentLoader,
                                        isStructuredUISending: viewModel.isSendingUIEvent,
                                        onStructuredUIAction: { actionId, componentId in
                                            Task {
                                                await viewModel.sendStructuredUIEvent(
                                                    actionId: actionId,
                                                    componentId: componentId
                                                )
                                            }
                                        }
                                    )
                                    if viewModel.shouldShowSendRetry(for: message) {
                                        MessageSendRetryBar(
                                            errorText: viewModel.pendingSendRetry?.errorDescription,
                                            isBusy: viewModel.isSending
                                        ) {
                                            Task { await viewModel.retryFailedSend() }
                                        }
                                    }
                                }
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
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dismissKeyboard()
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                    .defaultScrollAnchor(.bottom)
                    .scrollDismissesKeyboard(.interactively)
                    .onScrollGeometryChange(for: ScrollPaginationSample.self) { geometry in
                        ScrollPaginationSample(geometry: geometry)
                    } action: { _, current in
                        latestScrollSample = current
                        ChatPaginationLogger.scrollSample(current)
                        considerPaginationFromScrollGeometry(current)
                    }
                    .onScrollPhaseChange { _, newPhase, _ in
                        if newPhase == .interacting || newPhase == .decelerating || newPhase == .tracking {
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
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }

            ChatComposerView(viewModel: viewModel, voiceViewModel: voiceViewModel)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if voiceViewModel.phase != .idle {
                MicRecordControl(viewModel: voiceViewModel)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle(viewModel.session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("structured_ui.toolbar") {
                    Task { await viewModel.startStructuredUIFlow() }
                }
                .disabled(viewModel.isSendingUIEvent)
            }
        }
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
            viewModel.applyExternalAssistantPhase(parsed.phase, activityLabel: parsed.activityLabel)
        }
        .onAppear {
            voiceRouting.activeSessionId = viewModel.session.id
            voiceRouting.useKnowledgeBase = viewModel.useKnowledgeBase
            voiceRouting.usesComposerDraft = true
            voiceViewModel.deferToComposer = true
            voiceViewModel.onComposerRecordingFinished = { url in
                Task { await viewModel.enqueueVoiceRecording(audioURL: url) }
            }
            DebugQuickActionsController.shared.registerChatLogAttachHandler { url in
                viewModel.attachDebugLogFile(from: url)
            }
            if let pending = voiceRouting.pendingComposerVoice,
               pending.sessionId == viewModel.session.id {
                voiceRouting.pendingComposerVoice = nil
                Task { await viewModel.enqueueVoiceRecording(audioURL: pending.audioURL) }
            }
        }
        .onDisappear {
            voiceRouting.activeSessionId = nil
            voiceRouting.usesComposerDraft = false
            voiceViewModel.deferToComposer = false
            voiceViewModel.onComposerRecordingFinished = nil
            DebugQuickActionsController.shared.registerChatLogAttachHandler(nil)
        }
        .onChange(of: viewModel.composerDraft.text) { _, _ in
            viewModel.scheduleComposerDraftSave()
        }
        .onChange(of: scenePhase) { _, newPhase in
            voiceViewModel.handleScenePhaseChange(newPhase)
            if newPhase == .background || newPhase == .inactive {
                viewModel.persistComposerDraftNow()
                viewModel.persistInFlightReplySnapshot()
            }
            guard newPhase == .active else { return }
            Task {
                await viewModel.resumeAwaitingReplyIfNeeded()
                await viewModel.refresh()
            }
        }
        .onAppear {
            ChatSessionFocusTracker.shared.setFocusedSessionId(viewModel.session.id)
            Task { await viewModel.resumeAwaitingReplyIfNeeded() }
        }
        .onDisappear {
            viewModel.persistComposerDraftNow()
            if ChatSessionFocusTracker.shared.focusedSessionId == viewModel.session.id {
                ChatSessionFocusTracker.shared.setFocusedSessionId(nil)
            }
        }
        .alert("chat.alert_title", isPresented: Binding(
            get: { viewModel.errorMessage != nil && viewModel.pendingSendRetry == nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("common.ok", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var assistantReplyPhaseView: some View {
        switch viewModel.assistantReplyPhase {
        case .idle:
            EmptyView()
        case .waiting:
            AssistantPendingBubbleView(activityLabel: viewModel.cursorActivityLabel)
                .id("__kb_assistant_waiting__")
        case .streaming(let text) where text.isEmpty:
            AssistantPendingBubbleView(activityLabel: viewModel.cursorActivityLabel)
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
            if let sample = latestScrollSample, sample.isNearOldestEdge {
                userHasScrolled = true
                requestOlderMessagesIfNeeded(source: "post-arm-edge")
            }
        }
    }

    /// With a plain `VStack`, `onAppear` on bubbles fires once at layout — not when scrolling to the top.
    /// Use scroll geometry (near oldest edge) as the primary load-older trigger.
    private func considerPaginationFromScrollGeometry(_ sample: ScrollPaginationSample) {
        guard sample.isNearOldestEdge else { return }
        guard isChatScrollReady else { return }
        userHasScrolled = true
        requestOlderMessagesIfNeeded(source: "scroll-geometry")
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

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
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
