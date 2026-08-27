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
                    Text("voice.default_sheet_heading")
                } footer: {
                    Text("voice.default_sheet_body")
                }

                Section("session.duration") {
                    Picker("session.duration", selection: $selectedTTL) {
                        ForEach(DefaultVoiceSessionTTL.allCases) { ttl in
                            Text(ttl.label).tag(ttl)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("voice.default_sheet_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.set", action: onConfirm)
                }
            }
        }
    }
}
