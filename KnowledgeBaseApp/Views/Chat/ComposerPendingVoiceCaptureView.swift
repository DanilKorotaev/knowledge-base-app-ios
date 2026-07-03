import SwiftUI

struct ComposerPendingVoiceCaptureView: View {
    let capture: PendingVoiceCapture
    var onRetry: () -> Void
    var onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.title3)
                    .foregroundStyle(stateColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if case .failed(let message) = capture.state {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                if case .transcribing = capture.state {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if case .failed = capture.state {
                HStack(spacing: 10) {
                    Button("Повторить", action: onRetry)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button("Удалить", role: .destructive, action: onDiscard)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: 280, alignment: .leading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(stateColor.opacity(0.35), lineWidth: 1)
        )
    }

    private var title: String {
        switch capture.state {
        case .transcribing:
            return "Распознаём речь…"
        case .failed:
            return "Голосовое не распознано"
        }
    }

    private var stateColor: Color {
        switch capture.state {
        case .transcribing:
            return .accentColor
        case .failed:
            return .orange
        }
    }

    private var backgroundColor: Color {
        switch capture.state {
        case .transcribing:
            return Color.accentColor.opacity(0.08)
        case .failed:
            return Color.orange.opacity(0.1)
        }
    }
}
