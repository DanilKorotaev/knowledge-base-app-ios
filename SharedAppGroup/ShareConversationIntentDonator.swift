import Foundation
import Intents

/// Donates `INSendMessageIntent` so iOS can show recent KB sessions
/// in the share sheet conversation / contacts row (no App Store Connect
/// Messaging App Service entitlement required).
///
/// Uses Intents only (no IntentsUI / UIImage) so the same file compiles in
/// the Share Extension and the main app.
enum ShareConversationIntentDonator {
    static func donate(sessionId: String, title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = trimmedTitle.isEmpty ? "Chat" : trimmedTitle
        let handle = INPersonHandle(value: sessionId, type: .unknown)
        let person = INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: display,
            image: nil,
            contactIdentifier: nil,
            customIdentifier: sessionId
        )
        let intent = INSendMessageIntent(
            recipients: [person],
            outgoingMessageType: .outgoingMessageText,
            content: nil,
            speakableGroupName: INSpeakableString(spokenPhrase: display),
            conversationIdentifier: sessionId,
            serviceName: "Knowledge Base",
            sender: nil,
            attachments: nil
        )
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = INInteractionDirection.outgoing
        interaction.donate { error in
            if let error {
                #if DEBUG
                print("ShareConversationIntentDonator: \(error.localizedDescription)")
                #endif
            }
        }
    }
}
