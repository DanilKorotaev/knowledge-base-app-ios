import Foundation

@MainActor
@Observable
final class ChatViewModel {
    let session: KBSession
    var messages: [KBMessage] = []
    var draft = ""
    var useKnowledgeBase = true
    var isLoading = false
    var isSending = false
    var errorMessage: String?
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
        defer { isLoading = false }
        do {
            messages = try await client.fetchMessages(sessionId: session.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func send() async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        errorMessage = nil
        streamingAssistantText = nil
        defer {
            isSending = false
            streamingAssistantText = nil
        }
        do {
            let stream = try await client.streamTextMessage(
                sessionId: session.id,
                text: trimmed,
                useKnowledgeBase: useKnowledgeBase
            )
            draft = ""

            var thread = try await client.fetchMessages(sessionId: session.id)
            if let last = thread.last, last.role == .assistant {
                thread.removeLast()
                messages = thread
            } else {
                messages = thread
            }

            var accumulated = ""
            for try await chunk in stream {
                accumulated += chunk
                streamingAssistantText = accumulated
            }

            messages = try await client.fetchMessages(sessionId: session.id)
        } catch {
            errorMessage = error.localizedDescription
            await load()
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
        defer { isSending = false }
        let scoped = fileURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        do {
            messages = try await client.sendAttachment(
                sessionId: session.id,
                fileURL: fileURL,
                filename: filename,
                mimeType: mimeType,
                useKnowledgeBase: useKnowledgeBase
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
