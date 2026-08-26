import SwiftUI
import UIKit

struct MessageCopySheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    Text(text)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }

                Button {
                    UIPasteboard.general.string = text
                    didCopy = true
                } label: {
                    Label(
                        didCopy ? L10n.string("chat.copy_done") : L10n.string("chat.copy_all"),
                        systemImage: didCopy ? "checkmark" : "doc.on.doc"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle(L10n.string("chat.copy_sheet_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("chat.copy_sheet_done")) { dismiss() }
                }
            }
        }
    }
}
