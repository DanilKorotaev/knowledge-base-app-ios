import AVFoundation
import SwiftUI

struct VoiceMessageBubble: View {
    let attachment: KBAttachment
    let transcription: String?
    let collapsedByDefault: Bool
    let loader: KBAttachmentLoaderProtocol?

    @State private var isExpanded: Bool
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var loadError: String?
    @State private var timer: Timer?

    init(
        attachment: KBAttachment,
        transcription: String?,
        collapsedByDefault: Bool,
        loader: KBAttachmentLoaderProtocol?
    ) {
        self.attachment = attachment
        self.transcription = transcription
        self.collapsedByDefault = collapsedByDefault
        self.loader = loader
        _isExpanded = State(initialValue: !collapsedByDefault)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    Task { await togglePlayback() }
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                }
                .disabled(loadError != nil)

                ProgressView(value: progress)
                    .progressViewStyle(.linear)

                if collapsedByDefault {
                    Button {
                        withAnimation { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                }
            }

            if let loadError {
                Text(loadError)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let transcription {
                if isExpanded {
                    Text(transcription)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                } else {
                    Text(transcription.firstLinePreview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private func togglePlayback() async {
        if isPlaying {
            player?.pause()
            isPlaying = false
            stopTimer()
            return
        }
        if player == nil {
            await preparePlayer()
        }
        guard let player else { return }
        player.play()
        isPlaying = true
        startTimer()
    }

    private func preparePlayer() async {
        guard let path = attachment.downloadURL, let loader else {
            loadError = "Voice unavailable"
            return
        }
        do {
            let data = try await loader.fetchData(from: path)
            player = try AVAudioPlayer(data: data)
            player?.prepareToPlay()
            progress = 0
        } catch {
            loadError = "Could not load audio"
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            guard let player else { return }
            if player.duration > 0 {
                progress = player.currentTime / player.duration
            }
            if !player.isPlaying {
                isPlaying = false
                progress = 0
                stopTimer()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

private extension String {
    var firstLinePreview: String {
        split(whereSeparator: \.isNewline).first.map(String.init) ?? self
    }
}
