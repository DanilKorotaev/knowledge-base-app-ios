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
                    TextField("Session title", text: $title)
                        .textInputAutocapitalization(.sentences)
                } footer: {
                    Text("Renaming “\(sessionName)”.")
                }
            }
            .navigationTitle("Rename session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
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
