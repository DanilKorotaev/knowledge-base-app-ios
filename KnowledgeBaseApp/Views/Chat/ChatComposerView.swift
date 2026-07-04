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

    var body: some View {
        composerContent
            .padding(14)
            .background(composerPanelShape.fill(Color(.secondarySystemGroupedBackground)))
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .photosPicker(
                isPresented: $showGalleryPicker,
                selection: $photoPickerItems,
                maxSelectionCount: max(1, remainingAttachmentSlots),
                matching: .images
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
                        guard let data = try? await item.loadTransferable(type: Data.self) else {
                            viewModel.reportError("Could not read photo.")
                            continue
                        }
                        if !viewModel.addPhotoData(data) {
                            skippedLimit = true
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
                TextField("Message", text: $viewModel.composerDraft.text, axis: .vertical)
                    .lineLimit(1 ... 8)
                    .textFieldStyle(.plain)
                    .disabled(isBusy)
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
                Label("Photos", systemImage: "photo.on.rectangle")
            }
            .disabled(remainingAttachmentSlots == 0)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                }
            }
            Button {
                showFileImporter = true
            } label: {
                Label("Files", systemImage: "folder")
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
        .accessibilityLabel("Add attachment")
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
        .accessibilityLabel("Send")
    }
}
