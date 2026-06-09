import Foundation
import UIKit

/// Drives `ChatView` scroll without implicit `onChange` heuristics.
enum ChatScrollIntent: Equatable {
    case none
    case scrollToBottom
    case preserve(messageId: String)
}

@MainActor
@Observable
final class ChatViewModel {
    static let pageSize = 5

    let session: KBSession
    var messages: [KBMessage] = []
    var composerDraft = ChatComposerDraft()
    var useKnowledgeBase = true
    var isLoading = false
    var isLoadingOlder = false
    var isSending = false
    var isTranscribingVoice = false
    var errorMessage: String?
    var totalCount = 0
    var hasMoreOlder = false
    var scrollIntent: ChatScrollIntent = .none
    /// In-flight assistant reply UI (spinner, streaming text, finalize).
    var assistantReplyPhase: AssistantReplyPhase = .idle

    private var streamRevealContinuation: CheckedContinuation<Void, Never>?

    private let client: ChatAPIClientProtocol

    /// Backward-compatible alias for tests and legacy call sites.
    var draft: String {
        get { composerDraft.text }
        set { composerDraft.text = newValue }
    }

    var canSendComposer: Bool {
        composerDraft.canSend && !isSending && !isTranscribingVoice
    }

    init(session: KBSession, client: ChatAPIClientProtocol) {
        self.session = session
        self.client = client
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        scrollIntent = .none
        ChatPaginationLogger.initialLoadStarted(sessionId: session.id)
        defer { isLoading = false }
        do {
            let page = try await client.fetchMessagesPage(
                sessionId: session.id,
                limit: Self.pageSize,
                beforeMessageId: nil
            )
            apply(page: page, requestedLimit: Self.pageSize, kind: "initial")
        } catch {
            errorMessage = error.localizedDescription
            ChatPaginationLogger.loadFailed("initial", error: error.localizedDescription)
        }
    }

    func loadOlder() async {
        if !hasMoreOlder {
            ChatPaginationLogger.requestBlocked("hasMoreOlder=false", context: "viewModel.loadOlder")
            return
        }
        if isLoadingOlder {
            ChatPaginationLogger.requestBlocked("isLoadingOlder=true", context: "viewModel.loadOlder")
            return
        }
        if isLoading {
            ChatPaginationLogger.requestBlocked("isLoading=true", context: "viewModel.loadOlder")
            return
        }
        guard let anchorId = messages.first?.id else {
            ChatPaginationLogger.requestBlocked("messages.first=nil", context: "viewModel.loadOlder")
            return
        }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let page = try await client.fetchMessagesPage(
                sessionId: session.id,
                limit: Self.pageSize,
                beforeMessageId: anchorId
            )
            guard !page.messages.isEmpty else {
                hasMoreOlder = false
                ChatPaginationLogger.requestBlocked("empty page from API", context: "viewModel.loadOlder")
                return
            }
            let older = clamp(page.messages, to: Self.pageSize)
            messages = older + messages
            totalCount = page.total
            hasMoreOlder = page.hasMoreOlder
            scrollIntent = .preserve(messageId: anchorId)
            ChatPaginationLogger.pageApplied(
                kind: "older",
                messageIds: page.messages.map(\.id),
                total: page.total,
                hasMoreOlder: page.hasMoreOlder,
                windowCount: messages.count
            )
        } catch {
            errorMessage = error.localizedDescription
            ChatPaginationLogger.loadFailed("older", error: error.localizedDescription)
        }
    }

    func acknowledgeScrollIntent() {
        scrollIntent = .none
    }

    /// Called when the streaming bubble finishes its typewriter reveal in `finalizing`.
    func completeStreamRevealAnimation() {
        streamRevealContinuation?.resume()
        streamRevealContinuation = nil
    }

    func waitForStreamRevealAnimation() async {
        guard case .finalizing(let text) = assistantReplyPhase, !text.isEmpty else { return }
        let timeoutMs = min(30_000, max(800, text.count * 28))

        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    self.streamRevealContinuation = continuation
                }
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(timeoutMs))
                await MainActor.run {
                    self.completeStreamRevealAnimation()
                }
            }
            _ = await group.next()
            group.cancelAll()
        }
    }

    /// Applies streaming phase from voice send (`AssistantReplyPhaseNotification`).
    func applyExternalAssistantPhase(_ phase: AssistantReplyPhase) {
        assistantReplyPhase = phase
        if phase.showsPlaceholder {
            scrollIntent = .scrollToBottom
        }
    }

    func send() async {
        await sendComposed()
    }

    func removeAttachment(id: String) {
        composerDraft.attachments.removeAll { $0.id == id }
    }

    func removeVoiceClip(id: String) {
        if let clip = composerDraft.voiceClips.first(where: { $0.id == id }) {
            try? FileManager.default.removeItem(at: clip.audioURL)
        }
        composerDraft.voiceClips.removeAll { $0.id == id }
    }

    func addPendingAttachment(_ attachment: PendingAttachment) {
        composerDraft.attachments.append(attachment)
    }

    func addPhotoData(_ data: Data, filename: String = "photo.jpg") {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).jpg")
        do {
            try data.write(to: path)
            addPendingAttachment(
                PendingAttachment(
                    localURL: path,
                    kind: .image,
                    filename: filename,
                    mimeType: "image/jpeg",
                    fileSize: Int64(data.count)
                )
            )
        } catch {
            reportError(error.localizedDescription)
        }
    }

    func addCameraImage(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            reportError("Could not encode photo.")
            return
        }
        addPhotoData(data, filename: "camera.jpg")
    }

    func addFiles(from urls: [URL]) async {
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer {
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: url, to: dest)
                let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? NSNumber)?
                    .int64Value
                let mime = dest.kbPreferredMIMEType
                let kind: PendingAttachmentKind = mime.hasPrefix("image/") ? .image : .file
                addPendingAttachment(
                    PendingAttachment(
                        localURL: dest,
                        kind: kind,
                        filename: url.lastPathComponent,
                        mimeType: mime,
                        fileSize: size
                    )
                )
            } catch {
                reportError(error.localizedDescription)
            }
        }
    }

    func enqueueVoiceRecording(audioURL: URL) async {
        isTranscribingVoice = true
        errorMessage = nil
        defer { isTranscribingVoice = false }
        do {
            let transcription = try await client.transcribeVoiceRecording(audioFileURL: audioURL)
            let clip = PendingVoiceClip(audioURL: audioURL, transcriptionSegment: transcription)
            composerDraft.voiceClips.append(clip)
            composerDraft.appendTranscription(transcription)
        } catch {
            try? FileManager.default.removeItem(at: audioURL)
            errorMessage = error.localizedDescription
        }
    }

    func sendComposed() async {
        let route = ChatComposerSendPlanner.route(for: composerDraft)
        if case .unsupported(let message) = route {
            errorMessage = message
            return
        }

        isSending = true
        errorMessage = nil
        scrollIntent = .none
        defer { isSending = false }

        composerDraft.clear()

        switch route {
        case .unsupported:
            return
        case .textOnly(let text):
            await sendStreamingText(text, optimisticContent: text)
        case .singleAttachment(let attachment):
            await sendSingleAttachment(attachment)
        case .singleVoice(let clip, let text):
            await sendSingleVoice(clip: clip, text: text)
        }
    }

    private func sendStreamingText(_ text: String, optimisticContent: String) async {
        do {
            let optimisticUser = KBMessage(
                id: "kb-optimistic-\(UUID().uuidString)",
                role: .user,
                content: optimisticContent,
                createdAt: Date()
            )
            messages.append(optimisticUser)
            assistantReplyPhase = .waiting
            scrollIntent = .scrollToBottom

            let stream = try await client.streamTextMessage(
                sessionId: session.id,
                text: text,
                useKnowledgeBase: useKnowledgeBase
            )
            try await AssistantReplyStreamConsumer.consume(stream) { phase in
                assistantReplyPhase = phase
                scrollIntent = .scrollToBottom
            }
            await waitForStreamRevealAnimation()
            await reloadLatestWindow()
            assistantReplyPhase = .idle
        } catch {
            assistantReplyPhase = .idle
            errorMessage = error.localizedDescription
        }
    }

    private func sendSingleAttachment(_ attachment: PendingAttachment) async {
        let scoped = attachment.localURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                attachment.localURL.stopAccessingSecurityScopedResource()
            }
            try? FileManager.default.removeItem(at: attachment.localURL)
        }
        do {
            _ = try await client.sendAttachment(
                sessionId: session.id,
                fileURL: attachment.localURL,
                filename: attachment.filename,
                mimeType: attachment.mimeType,
                useKnowledgeBase: useKnowledgeBase
            )
            await reloadLatestWindow()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendSingleVoice(clip: PendingVoiceClip, text: String) async {
        defer {
            try? FileManager.default.removeItem(at: clip.audioURL)
        }
        do {
            let optimisticUser = KBMessage(
                id: "kb-optimistic-\(UUID().uuidString)",
                role: .user,
                content: text,
                createdAt: Date()
            )
            messages.append(optimisticUser)
            assistantReplyPhase = .waiting
            scrollIntent = .scrollToBottom

            let stream = try await client.streamVoiceMessage(
                sessionId: session.id,
                audioFileURL: clip.audioURL,
                text: text,
                useKnowledgeBase: useKnowledgeBase
            )
            try await AssistantReplyStreamConsumer.consume(stream) { phase in
                assistantReplyPhase = phase
                scrollIntent = .scrollToBottom
            }
            await waitForStreamRevealAnimation()
            await reloadLatestWindow()
            assistantReplyPhase = .idle
        } catch {
            assistantReplyPhase = .idle
            errorMessage = error.localizedDescription
        }
    }

    func reloadLatestWindow() async {
        let limit = max(messages.count + 2, Self.pageSize)
        do {
            let page = try await client.fetchMessagesPage(
                sessionId: session.id,
                limit: limit,
                beforeMessageId: nil
            )
            apply(page: page, requestedLimit: limit, kind: "reloadLatest")
            scrollIntent = .scrollToBottom
            assistantReplyPhase = .idle
        } catch {
            errorMessage = error.localizedDescription
            ChatPaginationLogger.loadFailed("reloadLatest", error: error.localizedDescription)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func reportError(_ message: String) {
        errorMessage = message
    }

    func sendAttachment(fileURL: URL, filename: String, mimeType: String) async {
        isSending = true
        errorMessage = nil
        scrollIntent = .none
        defer { isSending = false }
        let scoped = fileURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        do {
            _ = try await client.sendAttachment(
                sessionId: session.id,
                fileURL: fileURL,
                filename: filename,
                mimeType: mimeType,
                useKnowledgeBase: useKnowledgeBase
            )
            await reloadLatestWindow()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(page: KBMessagesPage, requestedLimit: Int, kind: String) {
        messages = clamp(page.messages, to: requestedLimit)
        totalCount = page.total
        let hasOlderByCount = page.total > messages.count
        hasMoreOlder = page.hasMoreOlder || hasOlderByCount
        ChatPaginationLogger.pageApplied(
            kind: kind,
            messageIds: messages.map(\.id),
            total: page.total,
            hasMoreOlder: hasMoreOlder,
            windowCount: messages.count
        )
    }

    private func clamp(_ list: [KBMessage], to limit: Int) -> [KBMessage] {
        guard list.count > limit else { return list }
        return Array(list.suffix(limit))
    }
}
