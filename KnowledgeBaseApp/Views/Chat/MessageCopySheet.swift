import SwiftUI
import UIKit

struct MessageCopySheet: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // UITextView (plain `.text`) — range selection + plain-string pasteboard.
                // SwiftUI `Text` + `textSelection` copies RTFD and often blocks partial select.
                SelectablePlainTextView(text: text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

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

/// Read-only selectable text that always puts **plain** UTF-8 on the pasteboard.
private struct SelectablePlainTextView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> PlainCopyTextView {
        let textView = PlainCopyTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.backgroundColor = .systemBackground
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        textView.textContainer.lineFragmentPadding = 0
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textColor = .label
        textView.dataDetectorTypes = []
        textView.linkTextAttributes = [:]
        // Avoid rich-text pasteboard flavors from attributed selections.
        textView.text = text
        return textView
    }

    func updateUIView(_ uiView: PlainCopyTextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.textColor = .label
    }
}

/// Forces `UIPasteboard.general.string` on Copy so Handoff / Universal Clipboard stay plain text.
private final class PlainCopyTextView: UITextView {
    override func copy(_ sender: Any?) {
        let selected = text(in: selectedTextRange ?? textRange(from: beginningOfDocument, to: endOfDocument)!)
        UIPasteboard.general.string = selected ?? text
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(copy(_:)) {
            return selectedRange.length > 0 || !(text ?? "").isEmpty
        }
        // Keep Share / Look Up etc.; block paste/cut in a read-only sheet.
        if action == #selector(cut(_:)) || action == #selector(paste(_:)) {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
}
