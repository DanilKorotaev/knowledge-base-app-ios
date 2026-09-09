import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

private struct PreviewImageItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// ChatGPT-style composer: text on top, + / mic / send on the bottom row.
struct ChatComposerView: View {
    @Bindable var viewModel: ChatViewModel
    @Bindable var voiceViewModel: VoiceRecordingViewModel

    @State private var showFileImporter = false
    @State private var showCamera = false
    @State private var showGalleryPicker = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var previewImageItem: PreviewImageItem?
    @State private var quickLookFileURL: URL?
    /// UIDropInteraction + SwiftUI.onDrop both fire for focused text drops ~5ms apart.
    @State private var lastDropHandledAt: Date?

    private var remainingAttachmentSlots: Int {
        ComposerAttachmentLimits.remainingFileSlots(
            currentCount: viewModel.composerDraft.attachments.count
        )
    }

    private var isBusy: Bool {
        viewModel.isSending || viewModel.isTranscribingVoice || voiceViewModel.isSendingVoice
    }

    private var showsTextFieldTranscribingIndicator: Bool {
        voiceViewModel.isTranscribing
    }

    private var hasDraftMedia: Bool {
        !viewModel.composerDraft.attachments.isEmpty
            || !viewModel.composerDraft.voiceClips.isEmpty
            || !viewModel.pendingVoiceCaptures.isEmpty
    }

    private var composerTextFieldHeight: CGFloat {
        ComposerTextFieldMetrics.height(
            text: viewModel.composerDraft.text,
            width: max(UIScreen.main.bounds.width - 68, 120),
            minimumLineCount: 1
        )
    }

    var body: some View {
        composerContent
            .padding(14)
            .background(composerPanelShape.fill(Color(.secondarySystemGroupedBackground)))
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .onDrop(
                of: [.image, .jpeg, .png, .heic, .heif, .gif, .webP, .fileURL],
                isTargeted: nil
            ) { providers in
                guard !isBusy else { return false }
                enqueueDropProviders(providers, source: "swiftui")
                return true
            }
            .photosPicker(
                isPresented: $showGalleryPicker,
                selection: $photoPickerItems,
                maxSelectionCount: max(1, remainingAttachmentSlots),
                matching: .any(of: [.images, .videos])
            )
            .onChange(of: photoPickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    var skippedLimit = false
                    for item in items {
                        if viewModel.remainingComposerAttachmentSlots == 0 {
                            skippedLimit = true
                            break
                        }
                        do {
                            let media = try await GalleryMediaImporter.importItem(item)
                            if !viewModel.addPendingAttachment(
                                PendingAttachment(
                                    localURL: media.localURL,
                                    kind: media.kind,
                                    filename: media.filename,
                                    mimeType: media.mimeType,
                                    fileSize: media.fileSize
                                )
                            ) {
                                skippedLimit = true
                            }
                        } catch {
                            viewModel.reportError(L10n.string("composer.gallery_import_failed"))
                        }
                    }
                    if skippedLimit {
                        viewModel.reportAttachmentLimitReached()
                    }
                    photoPickerItems = []
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    Task { await viewModel.addFiles(from: urls) }
                case .failure(let error):
                    viewModel.reportError(error.localizedDescription)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(
                    onImage: { image in
                        showCamera = false
                        Task { await viewModel.addCameraImage(image) }
                    },
                    onCancel: { showCamera = false }
                )
                .ignoresSafeArea()
            }
            .sheet(item: $previewImageItem) { item in
                ImagePreviewSheet(imageURL: item.url)
            }
            .quickLookPreview($quickLookFileURL)
    }

    private var composerPanelShape: some Shape {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
    }

    private var composerContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasDraftMedia {
                ComposerAttachmentStripView(
                    attachments: viewModel.composerDraft.attachments,
                    voiceClips: viewModel.composerDraft.voiceClips,
                    pendingVoiceCaptures: viewModel.pendingVoiceCaptures,
                    onRemoveAttachment: { viewModel.removeAttachment(id: $0) },
                    onRemoveVoiceClip: { viewModel.removeVoiceClip(id: $0) },
                    onRetryPendingVoiceCapture: { id in
                        Task { await viewModel.retryPendingVoiceCaptureTranscription(id: id) }
                    },
                    onDiscardPendingVoiceCapture: { viewModel.discardPendingVoiceCapture(id: $0) },
                    onTapImage: { previewImageItem = PreviewImageItem(url: $0) },
                    onTapFile: { quickLookFileURL = $0 }
                )
            }

            ZStack(alignment: .trailing) {
                ComposerPasteTextView(
                    text: $viewModel.composerDraft.text,
                    placeholder: L10n.string("composer.message_placeholder"),
                    isEnabled: !isBusy,
                    onPasteImages: { await pasteClipboardImages() },
                    onDropUIImages: { images in
                        enqueueDropUIImages(images, source: "uitext")
                    },
                    onDropProviders: { providers in
                        enqueueDropProviders(providers, source: "uitext")
                    },
                    onPasteImagesFailed: {
                        viewModel.reportError(L10n.string("composer.paste_image_failed"))
                    }
                )
                // SwiftUI owns height — UITextView only fills/scrolls inside this frame.
                .frame(maxWidth: .infinity)
                .frame(height: composerTextFieldHeight)
                .clipped()
                .padding(.horizontal, 2)

                if showsTextFieldTranscribingIndicator {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                }
            }

            HStack(alignment: .center, spacing: 0) {
                attachmentMenu
                Spacer(minLength: 8)
                HStack(spacing: 14) {
                    ChatMicButton(viewModel: voiceViewModel, style: .composer)
                        .opacity(voiceViewModel.phase == .idle ? 1 : 0.45)
                    sendButton
                }
            }
        }
    }

    private var attachmentMenu: some View {
        Menu {
            Button {
                showGalleryPicker = true
            } label: {
                Label("composer.photos_and_videos", systemImage: "photo.on.rectangle")
            }
            .disabled(remainingAttachmentSlots == 0)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    Label("composer.camera", systemImage: "camera")
                }
            }
            Button {
                showFileImporter = true
            } label: {
                Label("composer.files", systemImage: "folder")
            }
            .disabled(remainingAttachmentSlots == 0)
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.medium))
                .foregroundStyle(.primary)
                .symbolRenderingMode(.monochrome)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .disabled(isBusy)
        .tint(.primary)
        .accessibilityLabel(Text("composer.add_attachment_a11y"))
    }

    private var sendButton: some View {
        Button {
            Task { await viewModel.sendComposed() }
        } label: {
            Image(systemName: "arrow.up")
                .font(.body.weight(.bold))
                .foregroundStyle(viewModel.canSendComposer ? Color.black : Color.secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(viewModel.canSendComposer ? Color.white : Color.secondary.opacity(0.25))
                )
        }
        .disabled(!viewModel.canSendComposer || isBusy)
        .accessibilityLabel(Text("composer.send_a11y"))
    }

    private func enqueueDropUIImages(_ images: [UIImage], source: String) {
        guard claimDrop(source: source, itemCount: images.count) else { return }
        Task { await attachDroppedUIImages(images) }
    }

    private func enqueueDropProviders(_ providers: [NSItemProvider], source: String) {
        guard claimDrop(source: source, itemCount: providers.count) else { return }
        Task { await attachDroppedProviders(providers) }
    }

    private func claimDrop(source: String, itemCount: Int) -> Bool {
        let now = Date()
        if let last = lastDropHandledAt, now.timeIntervalSince(last) < 0.55 {
            ComposerPasteLogger.dropIgnoredDuplicate(source: source)
            return false
        }
        lastDropHandledAt = now
        ComposerPasteLogger.dropPerformed(itemCount: itemCount, focused: source == "uitext")
        return true
    }

    @discardableResult
    private func pasteClipboardImages() async -> Bool {
        guard !isBusy else { return false }
        let slots = viewModel.remainingComposerAttachmentSlots
        guard slots > 0 else {
            viewModel.reportAttachmentLimitReached()
            return false
        }
        let attachments = await ClipboardMediaImporter.loadAttachmentsFromPasteboard(maxCount: slots)
        guard !attachments.isEmpty else { return false }
        addImportedAttachments(attachments)
        return true
    }

    private func attachDroppedUIImages(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        let initialSlots = await MainActor.run { viewModel.remainingComposerAttachmentSlots }
        guard initialSlots > 0 else {
            await MainActor.run { viewModel.reportAttachmentLimitReached() }
            return
        }
        let startingCount = await MainActor.run { viewModel.composerDraft.attachments.count }
        let imported = ClipboardMediaImporter.attachments(fromImages: images, maxCount: initialSlots)
        await finishDropImport(imported, startingCount: startingCount, requestedCount: images.count)
    }

    private func attachDroppedProviders(_ providers: [NSItemProvider]) async {
        guard !providers.isEmpty else { return }

        let initialSlots = await MainActor.run { viewModel.remainingComposerAttachmentSlots }
        guard initialSlots > 0 else {
            await MainActor.run { viewModel.reportAttachmentLimitReached() }
            return
        }

        let startingCount = await MainActor.run { viewModel.composerDraft.attachments.count }
        var imported = await ClipboardMediaImporter.attachments(
            fromDropProviders: providers,
            maxCount: initialSlots
        )
        // Fresh screenshots often remain on the pasteboard even when the drop provider fails.
        if imported.isEmpty {
            imported = await ClipboardMediaImporter.loadAttachmentsFromPasteboard(maxCount: initialSlots)
            if !imported.isEmpty {
                ComposerPasteLogger.dropLoadFinished(count: imported.count, attempt: 2)
            }
        }
        await finishDropImport(imported, startingCount: startingCount, requestedCount: providers.count)
    }

    private func finishDropImport(
        _ imported: [PendingAttachment],
        startingCount: Int,
        requestedCount: Int
    ) async {
        await MainActor.run {
            let currentCount = viewModel.composerDraft.attachments.count
            if imported.isEmpty {
                if currentCount > startingCount { return }
                viewModel.reportError(L10n.string("composer.paste_image_failed"))
                return
            }
            addImportedAttachments(imported)
            if imported.count < requestedCount,
               viewModel.remainingComposerAttachmentSlots == 0 {
                viewModel.reportAttachmentLimitReached()
            }
        }
    }

    private func addImportedAttachments(_ attachments: [PendingAttachment]) {
        for attachment in attachments {
            guard viewModel.remainingComposerAttachmentSlots > 0 else {
                viewModel.reportAttachmentLimitReached()
                return
            }
            _ = viewModel.addPendingAttachment(attachment)
        }
    }
}
