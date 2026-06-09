import SwiftUI

struct AttachmentImageGrid: View {
    let attachments: [KBAttachment]
    let loader: KBAttachmentLoaderProtocol?
    let onSelect: (UIImage) -> Void

    private var columns: [GridItem] {
        attachments.count <= 1
            ? [GridItem(.flexible(), spacing: 8)]
            : [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(attachments) { attachment in
                AuthenticatedAttachmentImage(
                    attachment: attachment,
                    loader: loader,
                    layout: attachments.count <= 1 ? .hero : .thumbnail
                ) { image in
                    onSelect(image)
                }
            }
        }
    }
}

private enum AttachmentImageLayout {
    case hero
    case thumbnail
}

private struct AuthenticatedAttachmentImage: View {
    let attachment: KBAttachment
    let loader: KBAttachmentLoaderProtocol?
    let layout: AttachmentImageLayout
    let onTap: (UIImage) -> Void

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .modifier(ImageLayoutModifier(layout: layout))
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
            .modifier(ImageLayoutModifier(layout: layout))
            .overlay {
                Image(systemName: systemName)
                    .foregroundStyle(.secondary)
            }
    }

    private func load() async {
        if let local = localFileURL(from: attachment.downloadURL) {
            if let ui = UIImage(contentsOfFile: local.path) {
                image = ui
                return
            }
        }

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

    private func localFileURL(from downloadURL: String?) -> URL? {
        guard let downloadURL, downloadURL.hasPrefix("file://") else { return nil }
        return URL(string: downloadURL)
    }
}

private struct ImageLayoutModifier: ViewModifier {
    let layout: AttachmentImageLayout

    func body(content: Content) -> some View {
        switch layout {
        case .hero:
            content
                .scaledToFit()
                .frame(maxWidth: 280, maxHeight: 280)
        case .thumbnail:
            content
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 120, maxHeight: 120)
                .clipped()
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
