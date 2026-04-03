import SwiftUI

struct FileDiffView: View {
    let file: KBChangedFile
    let filesClient: FilesAPIClientProtocol
    var onReverted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmRevert = false
    @State private var isReverting = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(file.path)
                    .font(.title3.weight(.semibold))
                Text(file.changeKind)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 8) {
                    diffColumn(title: "Before", text: file.beforeText)
                    diffColumn(title: "After", text: file.afterText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Diff")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Revert", role: .destructive) {
                    confirmRevert = true
                }
                .disabled(isReverting)
            }
        }
        .confirmationDialog(
            "Revert this file to the previous version?",
            isPresented: $confirmRevert,
            titleVisibility: .visible
        ) {
            Button("Revert", role: .destructive) {
                Task { await revert() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Revert", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func diffColumn(title: String, text: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text ?? "—")
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    @MainActor
    private func revert() async {
        isReverting = true
        defer { isReverting = false }
        do {
            try await filesClient.revertFile(id: file.id)
            onReverted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
