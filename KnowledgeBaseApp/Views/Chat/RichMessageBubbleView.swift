import SwiftUI
import UIKit

struct RichMessageBubbleView: View {
    let message: KBMessage
    var filesClient: FilesAPIClientProtocol = Self.makeFilesClient()
    var attachmentLoader: KBAttachmentLoaderProtocol?
    var assistantResponseTime: TimeInterval?
    var isStructuredUISending: Bool = false
    /// When false, panels with structured UI are hidden (unused; prefer always true + read-only).
    var showsStructuredUI: Bool = true
    /// When false, panel is visible but not tappable (history / preference off).
    var isStructuredUIInteractive: Bool = true
    var onStructuredUIAction: ((String, String, [String: StructuredUIFormValue]?) -> Void)?

    @State private var fullscreenImage: IdentifiableImage?
    @State private var copySheetText: IdentifiableCopyText?

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
        .contentShape(Rectangle())
        .contextMenu {
            if MessageCopyContent.text(for: message) != nil {
                Button {
                    _ = MessageCopyContent.copyToPasteboard(message)
                } label: {
                    Label(L10n.string("chat.copy_all"), systemImage: "doc.on.doc")
                }
                Button {
                    if let text = MessageCopyContent.text(for: message) {
                        copySheetText = IdentifiableCopyText(text: text)
                    }
                } label: {
                    Label(L10n.string("chat.open_to_copy"), systemImage: "text.viewfinder")
                }
            }
        }
        .fullScreenCover(item: $fullscreenImage) { item in
            FullscreenImageViewer(image: item.image) {
                fullscreenImage = nil
            }
        }
        .sheet(item: $copySheetText) { item in
            MessageCopySheet(text: item.text)
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

            if !message.documentAttachments.isEmpty {
                MessageDocumentAttachmentsView(
                    attachments: message.documentAttachments,
                    loader: attachmentLoader
                )
            }

            if let text = message.bubbleTextContent {
                MessageContentView(message: message, contentOverride: text)
            }
            if message.role == .assistant, showsStructuredUI, let structuredUI = message.structuredUI {
                StructuredUIPanelView(
                    document: structuredUI,
                    isSending: isStructuredUISending,
                    isInteractive: isStructuredUIInteractive,
                    attachmentLoader: attachmentLoader,
                    onFullscreenImage: { image in
                        fullscreenImage = IdentifiableImage(image: image)
                    },
                    onAction: { actionId, componentId, values in
                        onStructuredUIAction?(actionId, componentId, values)
                    }
                )
            }
            if message.role == .assistant,
               let changedFiles = message.relatedChangedFiles,
               !changedFiles.isEmpty {
                ChangedFilesListView(
                    files: changedFiles,
                    filesClient: filesClient,
                    titleKey: message.showsRecentChangedFilesFallback
                        ? "chat.recent_changed_files"
                        : "chat.changed_files_in_reply"
                )
            } else if message.role == .assistant {
                OpenChangedFilesFallbackButton(filesClient: filesClient)
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

private extension RichMessageBubbleView {
    static func makeFilesClient() -> FilesAPIClientProtocol {
        URLSessionKnowledgeBaseAPIClient() ?? StubFilesAPIClient()
    }
}

private struct ChangedFilesListView: View {
    let files: [KBChangedFile]
    let filesClient: FilesAPIClientProtocol
    let titleKey: LocalizedStringKey

    /// Collapsed by default so long lists do not steal half the chat viewport.
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.snappy(duration: 0.28)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(titleKey)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(files.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(titleKey))
            .accessibilityValue(Text(isExpanded ? "common.expanded" : "common.collapsed"))
            .accessibilityHint(Text("chat.changed_files_a11y_hint"))

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(files) { file in
                        NavigationLink {
                            FileDiffView(file: file, filesClient: filesClient, onReverted: {})
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.secondary)
                                Text(file.path)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 0)
                                Text(file.changeKind)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 4)
        .animation(.snappy(duration: 0.28), value: isExpanded)
    }
}

private struct OpenChangedFilesFallbackButton: View {
    let filesClient: FilesAPIClientProtocol

    var body: some View {
        NavigationLink {
            ChangedFilesView(filesClient: filesClient)
        } label: {
            Label("chat.open_changed_files", systemImage: "doc.text.magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
                .padding(.top, 4)
        }
        .buttonStyle(.plain)
    }
}

private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct IdentifiableCopyText: Identifiable {
    let id = UUID()
    let text: String
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
