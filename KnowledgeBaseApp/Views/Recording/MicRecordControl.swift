import SwiftUI

/// Hold-to-record overlay: swipe hints while holding, compact controls when locked.
/// Gestures live on `ChatMicButton` in the composer — no duplicate mic icon here.
struct MicRecordControl: View {
    @Bindable var viewModel: VoiceRecordingViewModel

    var body: some View {
        Group {
            if viewModel.phase == .locked {
                lockedPanel
            } else if viewModel.phase == .holding {
                holdingPanel
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private var holdingPanel: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.open.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("voice.swipe_up_to_lock")
                .font(.caption)
                .foregroundStyle(.secondary)
            recordingTimeline
            Text("voice.swipe_left_hint")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var lockedPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isLockedRecordingPaused ? "pause.circle.fill" : "lock.fill")
                    .foregroundStyle(.secondary)
                Text(
                    viewModel.isLockedRecordingPaused
                        ? LocalizedStringKey("voice.recording_paused")
                        : LocalizedStringKey("voice.locked_recording")
                )
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }

            recordingTimeline

            HStack(spacing: 10) {
                Button(role: .cancel) {
                    viewModel.cancelLockedSession()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 22)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel(Text("common.cancel"))

                if viewModel.isLockedRecordingPaused {
                    Button {
                        viewModel.resumeLockedSession()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 22)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityLabel(Text("voice.resume"))
                } else {
                    Button {
                        viewModel.pauseLockedSession()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 22)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityLabel(Text("voice.pause"))
                }

                Button {
                    viewModel.sendLockedSession()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 22)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel(Text("voice.send"))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var recordingTimeline: some View {
        TimelineView(.periodic(from: .now, by: 0.05)) { context in
            VStack(spacing: 4) {
                RecordingWaveformView(level: viewModel.currentMeterLevelForDisplay())
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .opacity(viewModel.isLockedRecordingPaused ? 0.35 : 1)
                Text(durationLabel(at: context.date))
                    .font(.system(.subheadline, design: .monospaced))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func durationLabel(at date: Date) -> String {
        if viewModel.phase == .locked || viewModel.phase == .holding {
            return formatDuration(viewModel.recordingElapsedDuration(at: date))
        }
        guard let start = viewModel.recordingStartTime() else { return "0:00" }
        let sec = max(0, Int(date.timeIntervalSince(start)))
        return formatDuration(TimeInterval(sec))
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let sec = max(0, Int(interval.rounded(.down)))
        return String(format: "%d:%02d", sec / 60, sec % 60)
    }
}

private struct RecordingWaveformView: View {
    var level: Float

    var body: some View {
        GeometryReader { geo in
            let bars = 24
            let w = geo.size.width / CGFloat(bars)
            HStack(spacing: 0) {
                ForEach(0 ..< bars, id: \.self) { index in
                    let phase = Double(index) / Double(bars) * .pi * 2
                    let jitter = sin(phase + Double(level) * 6) * 0.35 + 1
                    let height = max(4, CGFloat(level) * geo.size.height * CGFloat(jitter))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(width: max(2, w - 2), height: height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .frame(minHeight: 28)
    }
}

#Preview {
    MicRecordControl(
        viewModel: VoiceRecordingViewModel(chatClient: StubChatAPIClient(store: InMemoryKBStore()))
    )
}
