import SwiftUI

struct ComposerFileChipView: View {
    let attachment: PendingAttachment
    var showsRemoveButton = true
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.kind.systemImageName)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename)
                    .font(.caption)
                    .lineLimit(1)
                if let size = attachment.fileSize {
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if showsRemoveButton {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ComposerVoiceChipView: View {
    let clip: PendingVoiceClip
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .foregroundStyle(.secondary)
            Text(clip.transcriptionSegment.isEmpty ? String(localized: "voice.note") : clip.transcriptionSegment)
                .font(.caption)
                .lineLimit(2)
                .frame(maxWidth: 140, alignment: .leading)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
