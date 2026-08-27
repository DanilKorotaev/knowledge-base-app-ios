import QuickLook
import SwiftUI
import UIKit

struct StructuredUIImageNodeView: View {
    let node: KBStructuredUINode
    var loader: KBAttachmentLoaderProtocol?
    var onFullscreen: ((UIImage) -> Void)?

    @State private var image: UIImage?
    @State private var failed = false

    private var contentMode: ContentMode {
        (node.contentMode?.lowercased() == "fill") ? .fill : .fit
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(maxWidth: .infinity, maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onTapGesture { onFullscreen?(image) }
                    .accessibilityLabel(Text(node.alt ?? node.label ?? "Image"))
            } else if failed {
                placeholder(systemName: "photo.badge.exclamationmark")
            } else {
                placeholder(systemName: "photo")
                    .overlay { ProgressView().scaleEffect(0.8) }
            }
        }
        .task(id: node.id) {
            await load()
        }
    }

    private func placeholder(systemName: String) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.secondary.opacity(0.12))
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .overlay {
                Image(systemName: systemName)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(Text(node.alt ?? L10n.string("structured_ui.image_unavailable")))
    }

    private func load() async {
        failed = false
        image = nil

        if let download = node.downloadURL, StructuredUIURLPolicy.isAllowedDownloadPath(download) {
            if download.hasPrefix("file://"), let fileURL = URL(string: download), fileURL.isFileURL,
               let ui = UIImage(contentsOfFile: fileURL.path) {
                image = ui
                return
            }
            guard let loader else {
                failed = true
                return
            }
            do {
                let data = try await loader.fetchData(from: download)
                if let ui = UIImage(data: data) {
                    image = ui
                } else {
                    failed = true
                }
            } catch {
                failed = true
            }
            return
        }

        guard let url = StructuredUIURLPolicy.allowedHTTPURL(from: node.url) else {
            failed = true
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                failed = true
                return
            }
            if let ui = UIImage(data: data) {
                image = ui
            } else {
                failed = true
            }
        } catch {
            failed = true
        }
    }
}

struct StructuredUILinkNodeView: View {
    let node: KBStructuredUINode
    @Environment(\.openURL) private var openURL

    private var destination: URL? {
        StructuredUIURLPolicy.allowedHTTPURL(from: node.url)
    }

    var body: some View {
        Button {
            guard let destination else { return }
            openURL(destination)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "link")
                Text(node.label ?? node.url ?? L10n.string("structured_ui.link_fallback"))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.body)
        }
        .buttonStyle(.bordered)
        .disabled(destination == nil)
        .accessibilityLabel(node.label ?? L10n.string("structured_ui.link_fallback"))
    }
}

struct StructuredUIFileNodeView: View {
    let node: KBStructuredUINode
    var loader: KBAttachmentLoaderProtocol?

    @State private var previewURL: URL?
    @State private var isLoading = false
    @State private var previewError: String?

    var body: some View {
        Button {
            Task { await openPreview() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.fileName ?? node.label ?? L10n.string("attachment.fallback_name"))
                        .font(.subheadline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let size = node.fileSize {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "eye")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLoading || !StructuredUIURLPolicy.isAllowedDownloadPath(node.downloadURL))
        .quickLookPreview($previewURL)
        .alert("preview.unavailable", isPresented: Binding(
            get: { previewError != nil },
            set: { if !$0 { previewError = nil } }
        )) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(previewError ?? "")
        }
    }

    @MainActor
    private func openPreview() async {
        guard !isLoading else { return }
        guard let download = node.downloadURL,
              StructuredUIURLPolicy.isAllowedDownloadPath(download) else {
            previewError = L10n.string("attachment.no_preview_url")
            return
        }
        isLoading = true
        defer { isLoading = false }

        let attachment = KBAttachment(
            id: node.id,
            fileType: "document",
            fileName: node.fileName ?? node.label,
            fileSize: node.fileSize,
            mimeType: nil,
            downloadURL: download,
            transcription: nil
        )
        do {
            previewURL = try await AttachmentPreviewURLResolver.resolveLocalURL(
                for: attachment,
                loader: loader
            )
        } catch {
            previewError = error.localizedDescription
        }
    }
}
