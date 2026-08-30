import AVKit
import SwiftUI

struct VideoMessageBubble: View {
    let attachment: KBAttachment
    let loader: KBAttachmentLoaderProtocol?

    @State private var showPlayer = false
    @State private var localURL: URL?
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        Button {
            Task { await openPlayer() }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 72, height: 48)
                    if isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.primary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(attachment.fileName ?? L10n.string("attachment.video_fallback"))
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if let size = attachment.fileSize {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .fullScreenCover(isPresented: $showPlayer) {
            if let localURL {
                NativeVideoPlayerView(url: localURL) {
                    showPlayer = false
                }
            }
        }
        .alert("preview.unavailable", isPresented: Binding(
            get: { loadError != nil },
            set: { if !$0 { loadError = nil } }
        )) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(loadError ?? "")
        }
    }

    @MainActor
    private func openPlayer() async {
        if localURL != nil {
            showPlayer = true
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            localURL = try await AttachmentPreviewURLResolver.resolveLocalURL(
                for: attachment,
                loader: loader
            )
            showPlayer = true
        } catch {
            loadError = StructuredUIErrorMessage.userFacing(error)
        }
    }
}

struct NativeVideoPlayerView: View {
    let url: URL
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: AVPlayer(url: url))
                .ignoresSafeArea()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.35))
                    .padding(12)
            }
            .accessibilityLabel(Text("common.close"))
        }
    }
}
