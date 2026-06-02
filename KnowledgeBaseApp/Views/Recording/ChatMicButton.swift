import SwiftUI

/// Compact hold-to-record mic for the chat input bar (same gestures as `MicRecordControl`).
struct ChatMicButton: View {
    @Bindable var viewModel: VoiceRecordingViewModel

    var body: some View {
        ZStack {
            Circle()
                .fill(viewModel.phase == .idle ? Color.accentColor.opacity(0.15) : Color.red.opacity(0.2))
                .frame(width: 36, height: 36)
            Image(systemName: "mic.fill")
                .font(.body)
                .foregroundStyle(viewModel.phase == .idle ? Color.accentColor : Color.red)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    viewModel.handleDragChanged(value.translation)
                }
                .onEnded { value in
                    viewModel.handleDragEnded(value.translation)
                }
        )
        .accessibilityLabel("Record voice")
        .disabled(viewModel.isSendingVoice)
    }
}
