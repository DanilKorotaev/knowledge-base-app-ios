import SwiftUI

struct ComposerAttachmentStripView: View {
    let attachments: [PendingAttachment]
    let voiceClips: [PendingVoiceClip]
    let pendingVoiceCaptures: [PendingVoiceCapture]
    var onRemoveAttachment: (String) -> Void
    var onRemoveVoiceClip: (String) -> Void
    var onRetryPendingVoiceCapture: (String) -> Void
    var onDiscardPendingVoiceCapture: (String) -> Void
    var onTapImage: (URL) -> Void
    var onTapFile: (URL) -> Void

    private var hasScrollableMedia: Bool {
        !attachments.isEmpty || !voiceClips.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(pendingVoiceCaptures) { capture in
                ComposerPendingVoiceCaptureView(
                    capture: capture,
                    onRetry: { onRetryPendingVoiceCapture(capture.id) },
                    onDiscard: { onDiscardPendingVoiceCapture(capture.id) }
                )
            }

            if hasScrollableMedia {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(attachments) { attachment in
                            attachmentPreview(attachment)
                        }
                        ForEach(voiceClips) { clip in
                            ComposerVoiceChipView(clip: clip) {
                                onRemoveVoiceClip(clip.id)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentPreview(_ attachment: PendingAttachment) -> some View {
        switch attachment.kind {
        case .image:
            ZStack(alignment: .topTrailing) {
                Button {
                    onTapImage(attachment.localURL)
                } label: {
                    if let image = UIImage(contentsOfFile: attachment.localURL.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        ComposerFileChipView(attachment: attachment, showsRemoveButton: false, onRemove: {})
                    }
                }
                .buttonStyle(.plain)

                Button {
                    onRemoveAttachment(attachment.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .offset(x: 6, y: -6)
            }
        case .video, .file:
            ComposerFileChipView(attachment: attachment) {
                onRemoveAttachment(attachment.id)
            }
            .onTapGesture {
                onTapFile(attachment.localURL)
            }
        }
    }
}
