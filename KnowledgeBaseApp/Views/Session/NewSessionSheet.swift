import SwiftUI

struct NewSessionSheet: View {
    @Binding var title: String
    let onCancel: () -> Void
    let onCreate: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Session title", text: $title)
                        .textInputAutocapitalization(.sentences)
                } footer: {
                    Text("Leave blank to use “New session”.")
                }
            }
            .navigationTitle("New session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: onCreate)
                }
            }
        }
    }
}

#Preview {
    NewSessionSheet(title: .constant(""), onCancel: {}, onCreate: {})
}
