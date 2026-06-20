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
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Sending…")
                        .font(.caption)
                }
            }
        }
        .navigationTitle(viewModel.phase == .idle ? "Knowledge Base" : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(viewModel.phase == .recording ? .hidden : .visible, for: .navigationBar)
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
        .onChange(of: viewModel.voiceContext.relayStatus) { _, _ in
            viewModel.syncRelayStatusMessage()
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
            VStack(spacing: 8) {
                sessionHeader
                relayStatusBanner

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
                        .multilineTextAlignment(.center)
                }

                if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if !viewModel.isPhoneReachable, viewModel.voiceContext.relayStatus != .processing {
                    Text("iPhone not reachable — file still queues via Bluetooth")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private var relayStatusBanner: some View {
        switch viewModel.voiceContext.relayStatus {
        case .processing:
            Label("Processing on iPhone…", systemImage: "iphone.and.arrow.forward")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .success:
            Label("Reply received", systemImage: "checkmark.circle")
                .font(.caption2)
                .foregroundStyle(.green)
        case .error:
            EmptyView()
        case .none:
            EmptyView()
        }
    }

    private var sessionHeader: some View {
        VStack(spacing: 2) {
            Text(viewModel.voiceContext.displaySessionTitle)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
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
        VStack(spacing: 10) {
            Image(systemName: "mic.fill")
                .font(.system(size: 36))
                .foregroundStyle(.red)
                .padding(.top, 4)

            Text("Recording")
                .font(.headline)

            if let start = viewModel.recordingStartDate {
                TimelineView(.periodic(from: start, by: 1)) { context in
                    Text(elapsed(since: start, now: context.date))
                        .font(.title3.monospacedDigit())
                }
            }

            MeterStrip(level: viewModel.meterLevelForDisplay())
                .frame(maxWidth: .infinity)
                .frame(height: 8)
                .padding(.horizontal, 8)

            HStack(spacing: 8) {
                Button("Cancel") {
                    viewModel.cancelRecording()
                }
                .frame(maxWidth: .infinity)

                Button("Send") {
                    viewModel.finishRecording()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
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
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.25))
                Capsule()
                    .fill(Color.red.opacity(0.9))
                    .frame(width: max(geo.size.width * CGFloat(level), geo.size.width * 0.04))
            }
        }
    }
}

extension Notification.Name {
    static let watchStartRecordingImmediately = Notification.Name("kb.watch.startRecordingImmediately")
}

#Preview {
    WatchMainView(viewModel: WatchVoiceViewModel())
}
