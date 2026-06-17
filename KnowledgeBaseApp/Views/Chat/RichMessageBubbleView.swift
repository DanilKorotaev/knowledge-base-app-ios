import SwiftUI
import UIKit

struct RichMessageBubbleView: View {
    let message: KBMessage
    var attachmentLoader: KBAttachmentLoaderProtocol?
    var assistantResponseTime: TimeInterval?

    @State private var fullscreenImage: IdentifiableImage?

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.role == .user {
                Spacer(minLength: 16)
            }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                messageContent
                    .frame(
                        maxWidth: message.role == .assistant ? .infinity : Self.maxBubbleWidth,
                        alignment: message.role == .user ? .trailing : .leading
                    )
                if let metadataText {
                    Text(metadataText)
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

    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                    transcription: voice.transcription,
                    showsTranscription: true,
                    collapsedByDefault: message.isCompositeAttachmentMessage,
                    loader: attachmentLoader
                )
            }

            if let text = message.bubbleTextContent {
                MessageContentView(message: message, contentOverride: text)
            }
        }
        .padding(message.role == .user ? 12 : 0)
        .background(message.role == .user ? Color.accentColor.opacity(0.22) : Color.clear)
        .clipShape(message.role == .user ? AnyShape(RoundedRectangle(cornerRadius: 18, style: .continuous)) : AnyShape(Rectangle()))
    }

    private static var maxBubbleWidth: CGFloat {
        let screenWidth = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.width ?? 390
        return min(560, screenWidth * 0.90)
    }

    private var metadataText: String? {
        guard let createdAt = message.createdAt else { return nil }
        var value = createdAt.formatted(date: .abbreviated, time: .shortened)
        if message.role == .assistant,
           let assistantResponseTime,
           assistantResponseTime.isFinite,
           assistantResponseTime >= 0 {
            value += " · \(Self.formatAssistantResponseTime(assistantResponseTime))"
        }
        return value
    }

    private static func formatAssistantResponseTime(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = [.dropLeading]
        return formatter.string(from: seconds) ?? String(format: "%.1fs", seconds)
    }
}

private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct AnyShape: Shape {
    private let pathBuilder: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}
