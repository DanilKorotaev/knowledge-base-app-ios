import Foundation
import Intents
import UIKit

/// Donates `INSendMessageIntent` so iOS can show recent KB sessions
/// in the share sheet conversation / contacts row (no App Store Connect
/// Messaging App Service entitlement required).
enum ShareConversationIntentDonator {
    static func donate(sessionId: String, title: String, image: UIImage? = nil) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = trimmedTitle.isEmpty ? "Chat" : trimmedTitle
        let handle = INPersonHandle(value: sessionId, type: .unknown)
        let personImage = image.map { INImage(uiImage: $0) }
        let person = INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: display,
            image: personImage,
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
        if let personImage {
            intent.setImage(personImage, forParameterNamed: \.speakableGroupName)
        }
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .outgoing
        interaction.donate { error in
            if let error {
                #if DEBUG
                print("ShareConversationIntentDonator: \(error.localizedDescription)")
                #endif
            }
        }
    }
}
