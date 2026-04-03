import SwiftUI

/// Hold-to-record, swipe left to cancel, swipe up to lock (Telegram-style). Requires mic permission.
struct MicRecordControl: View {
    @Bindable var viewModel: VoiceRecordingViewModel

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.phase == .locked {
                lockedPanel
            } else if viewModel.phase == .holding {
                holdingPanel
            }

            micButton
        }
        .padding(.vertical, 8)
    }

    private var holdingPanel: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.open.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Swipe up to lock")
                .font(.caption)
                .foregroundStyle(.secondary)
            TimelineView(.periodic(from: .now, by: 0.05)) { context in
                let _ = viewModel.refreshMeteringForDisplay()
                RecordingWaveformView(level: viewModel.displayedMeterLevel)
                    .frame(height: 36)
                Text(durationLabel(start: viewModel.recordingStartTime(), end: context.date))
                    .font(.system(.title3, design: .monospaced))
                    .monospacedDigit()
            }
            Text("Swipe left to cancel · Release to send")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var lockedPanel: some View {
        VStack(spacing: 12) {
            Label("Locked recording", systemImage: "lock.fill")
                .font(.headline)
            TimelineView(.periodic(from: .now, by: 0.05)) { context in
                let _ = viewModel.refreshMeteringForDisplay()
                RecordingWaveformView(level: viewModel.displayedMeterLevel)
                    .frame(height: 36)
                Text(durationLabel(start: viewModel.recordingStartTime(), end: context.date))
                    .font(.system(.title3, design: .monospaced))
                    .monospacedDigit()
            }
            HStack(spacing: 24) {
                Button(role: .cancel) {
                    viewModel.cancelLockedSession()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.sendLockedSession()
                } label: {
                    Label("Send", systemImage: "paperplane.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var micButton: some View {
        ZStack {
            Circle()
                .fill(viewModel.phase == .idle ? Color.accentColor.opacity(0.15) : Color.red.opacity(0.2))
                .frame(width: 72, height: 72)
            Image(systemName: "mic.fill")
                .font(.title)
                .foregroundStyle(viewModel.phase == .idle ? Color.accentColor : Color.red)
        }
        .opacity(viewModel.phase == .locked ? 0.35 : 1)
        .allowsHitTesting(viewModel.phase != .locked)
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
    }

    private func durationLabel(start: Date?, end: Date) -> String {
        guard let start else { return "0:00" }
        let sec = max(0, Int(end.timeIntervalSince(start)))
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
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}

#Preview {
    MicRecordControl(viewModel: VoiceRecordingViewModel())
}
