import QuickLook
import SwiftUI

struct MessageDocumentAttachmentsView: View {
    let attachments: [KBAttachment]
    var loader: KBAttachmentLoaderProtocol?

    @State private var previewURL: URL?
    @State private var loadingAttachmentID: String?
    @State private var previewError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(attachments) { attachment in
                Button {
                    Task { await openPreview(for: attachment) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.secondary)
                        Text(attachment.fileName ?? L10n.string("attachment.fallback_name"))
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                        if let size = attachment.fileSize {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if loadingAttachmentID == attachment.id {
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
                .disabled(loadingAttachmentID != nil)
            }
        }
        .padding(.top, 2)
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
    private func openPreview(for attachment: KBAttachment) async {
        guard loadingAttachmentID == nil else { return }
        loadingAttachmentID = attachment.id
        defer { loadingAttachmentID = nil }

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

enum AttachmentPreviewURLResolver {
    enum Error: LocalizedError {
        case missingDownloadURL
        case downloadFailed

        var errorDescription: String? {
            switch self {
            case .missingDownloadURL:
                return L10n.string("attachment.no_preview_url")
            case .downloadFailed:
                return L10n.string("attachment.download_failed")
            }
        }
    }

    static func resolveLocalURL(
        for attachment: KBAttachment,
        loader: KBAttachmentLoaderProtocol?
    ) async throws -> URL {
        guard let downloadPath = attachment.downloadURL, !downloadPath.isEmpty else {
            throw Error.missingDownloadURL
        }

        if downloadPath.hasPrefix("file://"), let url = URL(string: downloadPath), url.isFileURL {
            return url
        }

        if downloadPath.hasPrefix("/"), FileManager.default.fileExists(atPath: downloadPath) {
            return URL(fileURLWithPath: downloadPath)
        }

        guard let loader else {
            throw Error.downloadFailed
        }

        let data = try await loader.fetchData(from: downloadPath)
        let filename = attachment.fileName ?? "attachment"
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(filename)")
        try data.write(to: dest)
        return dest
    }
}
