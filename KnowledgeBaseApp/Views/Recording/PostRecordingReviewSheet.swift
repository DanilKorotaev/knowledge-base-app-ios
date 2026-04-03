import SwiftUI

struct PostRecordingReviewSheet: View {
    @Bindable var viewModel: VoiceRecordingViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Transcription will appear here after Whisper (KB App API)",
                        text: $viewModel.transcriptionDraft,
                        axis: .vertical
                    )
                    .lineLimit(4 ... 12)
                } header: {
                    Text("Review")
                } footer: {
                    Text("Edit text before sending. The backend will replace this with Whisper output later.")
                }
            }
            .navigationTitle("Voice note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        viewModel.dismissPostRecordReview()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        viewModel.confirmPostRecordUpload()
                    }
                }
            }
        }
    }
}

#Preview {
    PostRecordingReviewSheet(viewModel: VoiceRecordingViewModel())
}
