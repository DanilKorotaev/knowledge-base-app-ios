import SwiftUI

struct NewSessionSheet: View {
    @Binding var title: String
    @Binding var useKnowledgeBase: Bool
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

                Section {
                    Toggle(isOn: $useKnowledgeBase) {
                        Label("Use Knowledge Base", systemImage: "books.vertical")
                    }
                } footer: {
                    Text("When enabled, the assistant can search your knowledge base. This applies to the whole session.")
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
    NewSessionSheet(
        title: .constant(""),
        useKnowledgeBase: .constant(true),
        onCancel: {},
        onCreate: {}
    )
}
