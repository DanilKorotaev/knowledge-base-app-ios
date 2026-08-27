import SwiftUI

/// Compact hold-to-record mic for the chat input bar (same gestures as `MicRecordControl`).
struct ChatMicButton: View {
    enum Style {
        case accentCircle
        case composer
    }

    @Bindable var viewModel: VoiceRecordingViewModel
    var style: Style = .accentCircle

    var body: some View {
        Group {
            switch style {
            case .accentCircle:
                accentCircleBody
            case .composer:
                composerBody
            }
        }
        .gesture(recordGesture)
        .accessibilityLabel(Text("voice.record_a11y"))
        .disabled(viewModel.isSendingVoice)
    }

    private var accentCircleBody: some View {
        ZStack {
            Circle()
                .fill(viewModel.phase == .idle ? Color.accentColor.opacity(0.15) : Color.red.opacity(0.2))
                .frame(width: 36, height: 36)
            Image(systemName: "mic.fill")
                .font(.body)
                .foregroundStyle(viewModel.phase == .idle ? Color.accentColor : Color.red)
        }
    }

    private var composerBody: some View {
        Image(systemName: viewModel.phase == .idle ? "mic" : "mic.fill")
            .font(.title3)
            .foregroundStyle(viewModel.phase == .idle ? Color.primary : Color.red)
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
    }

    private var recordGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                viewModel.handleDragChanged(value.translation)
            }
            .onEnded { value in
                viewModel.handleDragEnded(value.translation)
            }
    }
}
