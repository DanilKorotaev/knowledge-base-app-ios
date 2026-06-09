import SwiftUI

struct DefaultVoiceSessionTTLSheet: View {
    let session: KBSession
    @Binding var selectedTTL: DefaultVoiceSessionTTL
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(session.title)
                        .font(.headline)
                } header: {
                    Text("Default voice session")
                } footer: {
                    Text("Voice from the home screen, widget, or Watch will go to this session when no chat is open.")
                }

                Section("Duration") {
                    Picker("Duration", selection: $selectedTTL) {
                        ForEach(DefaultVoiceSessionTTL.allCases) { ttl in
                            Text(ttl.label).tag(ttl)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Voice default")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set", action: onConfirm)
                }
            }
        }
    }
}
