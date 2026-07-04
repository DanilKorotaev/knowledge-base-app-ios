import SwiftUI

struct ComposerPendingVoiceCaptureView: View {
    let capture: PendingVoiceCapture
    var onRetry: () -> Void
    var onDiscard: () -> Void

    var body: some View {
        Group {
            switch capture.state {
            case .transcribing:
                transcribingRow
            case .failed(let message):
                failedCard(message: message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var transcribingRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.body)
                .foregroundStyle(Color.accentColor)

            Text("Распознаём речь…")
                .font(.subheadline.weight(.medium))

            Spacer(minLength: 8)

            ProgressView()
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func failedCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "waveform.badge.exclamationmark")
                    .font(.body)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Голосовое не распознано")
                        .font(.subheadline.weight(.semibold))
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button("Повторить", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Удалить", role: .destructive, action: onDiscard)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }
}
