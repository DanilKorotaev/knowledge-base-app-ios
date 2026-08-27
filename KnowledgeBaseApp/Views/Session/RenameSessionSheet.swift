import SwiftUI

struct RenameSessionSheet: View {
    @Binding var title: String
    let sessionName: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("session.title_field", text: $title)
                        .textInputAutocapitalization(.sentences)
                } footer: {
                    Text(L10n.format("session.rename_hint_format", sessionName))
                }
            }
            .navigationTitle("session.rename_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: onSave)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    RenameSessionSheet(
        title: .constant("Work"),
        sessionName: "Demo",
        onCancel: {},
        onSave: {}
    )
}
