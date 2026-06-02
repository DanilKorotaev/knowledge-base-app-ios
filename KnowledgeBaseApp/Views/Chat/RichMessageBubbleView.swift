import SwiftUI
import UIKit

struct RichMessageBubbleView: View {
    let message: KBMessage
    var attachmentLoader: KBAttachmentLoaderProtocol?

    @State private var fullscreenImage: IdentifiableImage?

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 56)
            }
            bubbleContent
            if message.role == .assistant {
                Spacer(minLength: 56)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .fullScreenCover(item: $fullscreenImage) { item in
            FullscreenImageViewer(image: item.image) {
                fullscreenImage = nil
            }
        }
    }

    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !message.imageAttachments.isEmpty {
                AttachmentImageGrid(
                    attachments: message.imageAttachments,
                    loader: attachmentLoader
                ) { image in
                    fullscreenImage = IdentifiableImage(image: image)
                }
            }

            ForEach(message.voiceAttachments) { voice in
                VoiceMessageBubble(
                    attachment: voice,
                    transcription: voice.transcription ?? message.transcription,
                    collapsedByDefault: message.isVoiceOnly,
                    loader: attachmentLoader
                )
            }

            if shouldShowTextContent {
                MessageContentView(message: message)
            }
        }
        .padding(12)
        .background(
            message.role == .user
                ? Color.accentColor.opacity(0.22)
                : Color.secondary.opacity(0.14)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var shouldShowTextContent: Bool {
        let text = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return false }
        if message.isVoiceOnly { return false }
        return true
    }
}

private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
