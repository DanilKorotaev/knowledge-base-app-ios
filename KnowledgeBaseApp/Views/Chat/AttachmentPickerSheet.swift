import SwiftUI

struct AttachmentPickerSheet: View {
    var onPickFile: () -> Void
    var onPickCamera: () -> Void
    var onPickGallery: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    dismiss()
                    onPickGallery()
                } label: {
                    Label("attach.gallery", systemImage: "photo.on.rectangle")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        dismiss()
                        onPickCamera()
                    } label: {
                        Label("attach.camera", systemImage: "camera.fill")
                    }
                }
                Button {
                    dismiss()
                    onPickFile()
                } label: {
                    Label("attach.file", systemImage: "doc.fill")
                }
            }
            .navigationTitle("attach.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(240)])
    }
}
