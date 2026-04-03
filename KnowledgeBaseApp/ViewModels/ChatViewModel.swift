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
        defer { isSending = false }
        do {
            messages = try await client.sendTextMessage(
                sessionId: session.id,
                text: trimmed,
                useKnowledgeBase: useKnowledgeBase
            )
            draft = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
