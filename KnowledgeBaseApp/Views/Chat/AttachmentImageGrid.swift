import SwiftUI

struct AttachmentImageGrid: View {
    let attachments: [KBAttachment]
    let loader: KBAttachmentLoaderProtocol?
    let onSelect: (UIImage) -> Void

    private let columns = [GridItem(.adaptive(minimum: 96, maximum: 160), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(attachments) { attachment in
                AuthenticatedAttachmentImage(attachment: attachment, loader: loader) { image in
                    onSelect(image)
                }
                .frame(minHeight: 96)
            }
        }
    }
}

private struct AuthenticatedAttachmentImage: View {
    let attachment: KBAttachment
    let loader: KBAttachmentLoaderProtocol?
    let onTap: (UIImage) -> Void

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: 160, minHeight: 96, maxHeight: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onTapGesture { onTap(image) }
            } else if failed {
                placeholder(systemName: "photo.badge.exclamationmark")
            } else {
                placeholder(systemName: "photo")
                    .overlay { ProgressView().scaleEffect(0.8) }
            }
        }
        .task(id: attachment.id) {
            await load()
        }
    }

    private func placeholder(systemName: String) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.secondary.opacity(0.12))
            .frame(maxWidth: 160, minHeight: 96, maxHeight: 160)
            .overlay {
                Image(systemName: systemName)
                    .foregroundStyle(.secondary)
            }
    }

    private func load() async {
        guard let path = attachment.downloadURL, let loader else {
            failed = true
            return
        }
        do {
            let data = try await loader.fetchData(from: path)
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

struct FullscreenImageViewer: View {
    let image: UIImage
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.35))
                    .padding()
            }
        }
    }
}
