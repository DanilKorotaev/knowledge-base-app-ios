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
                    Label("Gallery", systemImage: "photo.on.rectangle")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        dismiss()
                        onPickCamera()
                    } label: {
                        Label("Camera", systemImage: "camera.fill")
                    }
                }
                Button {
                    dismiss()
                    onPickFile()
                } label: {
                    Label("File", systemImage: "doc.fill")
                }
            }
            .navigationTitle("Attach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(240)])
    }
}
