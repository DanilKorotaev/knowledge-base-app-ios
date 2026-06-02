import SwiftUI
import UIKit

struct RichMessageBubbleView: View {
    let message: KBMessage
    var attachmentLoader: KBAttachmentLoaderProtocol?

    @State private var fullscreenImage: IdentifiableImage?

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 16)
            }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                bubbleContent
                    .frame(maxWidth: Self.maxBubbleWidth, alignment: message.role == .user ? .trailing : .leading)
                if let createdAt = message.createdAt {
                    Text(createdAt, format: .dateTime.day().month(.abbreviated).hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            if message.role == .assistant {
                Spacer(minLength: 16)
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
                    transcription: message.isSingleVoiceOnlyMessage
                        ? (voice.transcription ?? message.transcription)
                        : nil,
                    showsTranscription: message.isSingleVoiceOnlyMessage,
                    collapsedByDefault: message.isSingleVoiceOnlyMessage,
                    loader: attachmentLoader
                )
            }

            if let text = message.bubbleTextContent {
                MessageContentView(message: message, contentOverride: text)
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

    private static var maxBubbleWidth: CGFloat {
        let screenWidth = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.width ?? 390
        return min(560, screenWidth * 0.90)
    }
}

private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
