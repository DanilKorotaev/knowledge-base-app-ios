import SwiftUI

struct WatchMainView: View {
    @Bindable var viewModel: WatchVoiceViewModel
    @State private var autoStartRecording = false

    var body: some View {
        Group {
            switch viewModel.phase {
            case .idle:
                idleContent
            case .recording:
                WatchRecordView(viewModel: viewModel)
            case .sending:
                ProgressView("Sending…")
            }
        }
        .navigationTitle("Knowledge Base")
        .onAppear {
            viewModel.onAppear()
            if autoStartRecording {
                autoStartRecording = false
                viewModel.startRecording()
            }
        }
        .onChange(of: viewModel.isPhoneReachable) { _, _ in
            viewModel.onReachabilityChanged()
            viewModel.reloadPending()
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchStartRecordingImmediately)) { _ in
            if viewModel.phase == .idle {
                viewModel.startRecording()
            } else {
                autoStartRecording = true
            }
        }
    }

    private var idleContent: some View {
        ScrollView {
            VStack(spacing: 10) {
                sessionHeader

                Button {
                    viewModel.startRecording()
                } label: {
                    Label("Record", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                if viewModel.pendingCount > 0 {
                    Text("\(viewModel.pendingCount) pending")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                if let preview = viewModel.voiceContext.lastResponsePreview, !preview.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last reply")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(preview)
                            .font(.caption)
                        Button("Speak") {
                            viewModel.speakLastResponse()
                        }
                        .font(.caption2)
                    }
                }

                if let error = viewModel.voiceContext.lastResponseError, !error.isEmpty {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.isPhoneReachable {
                    Text("iPhone not reachable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var sessionHeader: some View {
        VStack(spacing: 2) {
            Text(viewModel.voiceContext.displaySessionTitle)
                .font(.headline)
                .multilineTextAlignment(.center)
            if viewModel.voiceContext.isDefaultExpired {
                Text("Default expired")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}

struct WatchRecordView: View {
    @Bindable var viewModel: WatchVoiceViewModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.title)
                .foregroundStyle(.red)
            Text("Recording")
                .font(.headline)
            if let start = viewModel.recordingStartDate {
                TimelineView(.periodic(from: start, by: 1)) { context in
                    Text(elapsed(since: start, now: context.date))
                        .font(.caption.monospacedDigit())
                }
            }
            MeterStrip(level: viewModel.meterLevelForDisplay())
                .frame(height: 24)

            HStack {
                Button("Cancel") {
                    viewModel.cancelRecording()
                }
                Button("Send") {
                    viewModel.finishRecording()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private func elapsed(since start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct MeterStrip: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width * CGFloat(level)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.red.opacity(0.85))
                .frame(width: max(width, 4), height: geo.size.height, alignment: .leading)
        }
    }
}

extension Notification.Name {
    static let watchStartRecordingImmediately = Notification.Name("kb.watch.startRecordingImmediately")
}

#Preview {
    WatchMainView(viewModel: WatchVoiceViewModel())
}
