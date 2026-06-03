import Foundation

@MainActor
@Observable
final class ChatViewModel {
    static let pageSize = 5

    let session: KBSession
    var messages: [KBMessage] = []
    var draft = ""
    var useKnowledgeBase = true
    var isLoading = false
    var isLoadingOlder = false
    var isSending = false
    var errorMessage: String?
    var totalCount = 0
    var hasMoreOlder = false
    /// After prepending older messages, ChatView scrolls to this id to keep position.
    var scrollAnchorMessageId: String?
    /// Growing assistant text while `streamTextMessage` is active (hidden once final thread is loaded).
    var streamingAssistantText: String?

    private let client: ChatAPIClientProtocol

    init(session: KBSession, client: ChatAPIClientProtocol) {
        self.session = session
        self.client = client
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        scrollAnchorMessageId = nil
        defer { isLoading = false }
        do {
            let page = try await client.fetchMessagesPage(
                sessionId: session.id,
                limit: Self.pageSize,
                beforeMessageId: nil
            )
            apply(page: page, requestedLimit: Self.pageSize)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadOlder() async {
        guard hasMoreOlder, !isLoadingOlder, !isLoading else { return }
        guard let oldestId = messages.first?.id else { return }
        isLoadingOlder = true
        scrollAnchorMessageId = oldestId
        defer { isLoadingOlder = false }
        do {
            let page = try await client.fetchMessagesPage(
                sessionId: session.id,
                limit: Self.pageSize,
                beforeMessageId: oldestId
            )
            guard !page.messages.isEmpty else {
                hasMoreOlder = false
                scrollAnchorMessageId = nil
                return
            }
            let older = clamp(page.messages, to: Self.pageSize)
            messages = older + messages
            totalCount = page.total
            hasMoreOlder = page.hasMoreOlder
        } catch {
            errorMessage = error.localizedDescription
            scrollAnchorMessageId = nil
        }
    }

    func send() async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        errorMessage = nil
        streamingAssistantText = nil
        scrollAnchorMessageId = nil
        defer {
            isSending = false
            streamingAssistantText = nil
        }
        do {
            draft = ""
            let optimisticUser = KBMessage(
                id: "kb-optimistic-\(UUID().uuidString)",
                role: .user,
                content: trimmed,
                createdAt: Date()
            )
            messages.append(optimisticUser)

            let stream = try await client.streamTextMessage(
                sessionId: session.id,
                text: trimmed,
                useKnowledgeBase: useKnowledgeBase
            )

            var accumulated = ""
            for try await chunk in stream {
                accumulated += chunk
                streamingAssistantText = accumulated
            }

            await reloadLatestWindow()
        } catch {
            errorMessage = error.localizedDescription
            await load()
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
            apply(page: page, requestedLimit: limit)
        } catch {
            errorMessage = error.localizedDescription
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
        scrollAnchorMessageId = nil
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

    private func apply(page: KBMessagesPage, requestedLimit: Int) {
        messages = clamp(page.messages, to: requestedLimit)
        totalCount = page.total
        let hasOlderByCount = page.total > messages.count
        hasMoreOlder = page.hasMoreOlder || hasOlderByCount
    }

    private func clamp(_ list: [KBMessage], to limit: Int) -> [KBMessage] {
        guard list.count > limit else { return list }
        return Array(list.suffix(limit))
    }
}
