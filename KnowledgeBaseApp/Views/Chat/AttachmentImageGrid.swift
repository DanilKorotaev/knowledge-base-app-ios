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

    @State private var showShareSheet = false
    @State private var dragOffset: CGFloat = 0
    @State private var backgroundOpacity: Double = 1
    @State private var zoomScale: CGFloat = 1
    @State private var minimumZoomScale: CGFloat = 1

    private var canDismissByDrag: Bool {
        zoomScale <= minimumZoomScale + 0.02
    }

    var body: some View {
        ZStack {
            Color.black.opacity(backgroundOpacity).ignoresSafeArea()
            ZoomableImageView(image: image) { current, minimum in
                zoomScale = current
                minimumZoomScale = minimum
            }
            .offset(y: dragOffset)
            .scaleEffect(dismissScale)
            .ignoresSafeArea()
            .gesture(dismissDragGesture)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                    .accessibilityLabel(Text("structured_ui.share_image"))

                    Button {
                        dismissAnimated()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.35))
                            .padding(8)
                    }
                    .accessibilityLabel(Text("common.close"))
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .opacity(backgroundOpacity)
                Spacer()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [image])
        }
        .onAppear {
            minimumZoomScale = 1
            zoomScale = 1
        }
    }

    private var dismissScale: CGFloat {
        guard dragOffset > 0 else { return 1 }
        return max(0.82, 1 - dragOffset / 900)
    }

    private var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                guard canDismissByDrag, value.translation.height > 0 else { return }
                dragOffset = value.translation.height
                backgroundOpacity = Double(max(0.35, 1 - value.translation.height / 320))
            }
            .onEnded { value in
                guard canDismissByDrag else { return }
                let shouldDismiss = value.translation.height > 120
                    || value.predictedEndTranslation.height > 220
                if shouldDismiss {
                    dismissAnimated()
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        dragOffset = 0
                        backgroundOpacity = 1
                    }
                }
            }
    }

    private func dismissAnimated() {
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = 500
            backgroundOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onDismiss()
        }
    }
}
