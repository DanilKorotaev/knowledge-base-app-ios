import SwiftUI
import UIKit

/// Growing composer text view that turns image paste into attachments instead of ignoring them.
struct ComposerPasteTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isEnabled: Bool
    var onPasteImages: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PasteAwareTextView {
        let textView = PasteAwareTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.isScrollEnabled = false
        textView.keyboardDismissMode = .interactive
        // Keep compact in SwiftUI layouts — do not expand to fill leftover chat height.
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.onPasteImages = {
            context.coordinator.parent.onPasteImages()
        }
        context.coordinator.placeholderLabel = makePlaceholderLabel(in: textView)
        context.coordinator.updatePlaceholderVisibility(in: textView)
        return textView
    }

    func updateUIView(_ textView: PasteAwareTextView, context: Context) {
        context.coordinator.parent = self
        textView.onPasteImages = {
            context.coordinator.parent.onPasteImages()
        }
        textView.isEditable = isEnabled
        textView.isUserInteractionEnabled = isEnabled
        if textView.text != text {
            textView.text = text
            textView.invalidateIntrinsicContentSize()
        }
        context.coordinator.placeholderLabel?.text = placeholder
        context.coordinator.updatePlaceholderVisibility(in: textView)
    }

    private func makePlaceholderLabel(in textView: PasteAwareTextView) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .placeholderText
        label.numberOfLines = 1
        textView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: textView.trailingAnchor),
            label.topAnchor.constraint(equalTo: textView.topAnchor, constant: 2),
        ])
        return label
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ComposerPasteTextView
        weak var placeholderLabel: UILabel?

        init(_ parent: ComposerPasteTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
            updatePlaceholderVisibility(in: textView)
            textView.invalidateIntrinsicContentSize()
        }

        func updatePlaceholderVisibility(in textView: UITextView) {
            placeholderLabel?.isHidden = !(textView.text ?? "").isEmpty
        }
    }
}

final class PasteAwareTextView: UITextView {
    var onPasteImages: (() -> Void)?

    private let minHeight: CGFloat = 24
    /// ~8 lines of body text — matches previous TextField lineLimit(1...8).
    private let maxHeight: CGFloat = 176

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 1 ? bounds.width : (superview?.bounds.width ?? UIScreen.main.bounds.width - 48)
        let fitting = sizeThatFits(CGSize(width: max(width, 1), height: .greatestFiniteMagnitude))
        let height = min(max(fitting.height, minHeight), maxHeight)
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let shouldScroll = bounds.height >= maxHeight - 0.5
        if isScrollEnabled != shouldScroll {
            isScrollEnabled = shouldScroll
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)), ClipboardMediaImporter.pasteboardHasImages {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override func paste(_ sender: Any?) {
        if ClipboardMediaImporter.pasteboardHasImages {
            // Attach images; do not insert binary/image representations into the text field.
            onPasteImages?()
            return
        }
        super.paste(sender)
    }
}
