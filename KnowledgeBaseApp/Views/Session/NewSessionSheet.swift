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
                    TextField("session.title_field", text: $title)
                        .textInputAutocapitalization(.sentences)
                } footer: {
                    Text("session.new_blank_hint")
                }

                Section {
                    Toggle(isOn: $useKnowledgeBase) {
                        Label("session.use_kb", systemImage: "books.vertical")
                    }
                } footer: {
                    Text("session.use_kb_footer")
                }
            }
            .navigationTitle("session.new_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.create", action: onCreate)
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
