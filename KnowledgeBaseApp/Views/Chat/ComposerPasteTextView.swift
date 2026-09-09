import SwiftUI
import UIKit

/// Paste-aware composer text view. Height is owned by SwiftUI (`.frame(height:)`); this view fills and scrolls.
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
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 6, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = false
        textView.clipsToBounds = true
        // Do not drag-dismiss keyboard while scrolling composer text — only the chat list does that.
        textView.keyboardDismissMode = .none
        textView.setContentHuggingPriority(.defaultLow, for: .vertical)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
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
            label.topAnchor.constraint(equalTo: textView.topAnchor, constant: 4),
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
        }

        func updatePlaceholderVisibility(in textView: UITextView) {
            placeholderLabel?.isHidden = !(textView.text ?? "").isEmpty
        }
    }
}

final class PasteAwareTextView: UITextView {
    var onPasteImages: (() -> Void)?

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)), ClipboardMediaImporter.pasteboardHasImages {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override func paste(_ sender: Any?) {
        if ClipboardMediaImporter.pasteboardHasImages {
            ComposerPasteLogger.pasteInvoked(
                hasImages: true,
                itemCount: UIPasteboard.general.numberOfItems
            )
            onPasteImages?()
            return
        }
        ComposerPasteLogger.pasteInvoked(
            hasImages: false,
            itemCount: UIPasteboard.general.numberOfItems
        )
        super.paste(sender)
    }
}

/// Computes composer text-field height in SwiftUI so UITextView cannot stretch the panel.
enum ComposerTextFieldMetrics {
    /// Cap growth so the keyboard + composer leave room for chat history.
    static let maxLines = 4
    static let verticalInsets: CGFloat = 10

    static func height(
        text: String,
        width: CGFloat,
        minimumLineCount: Int,
        font: UIFont = UIFont.preferredFont(forTextStyle: .body)
    ) -> CGFloat {
        let minLines = max(1, minimumLineCount)
        let minHeight = ceil(font.lineHeight * CGFloat(minLines) + verticalInsets)
        let maxHeight = ceil(font.lineHeight * CGFloat(maxLines) + verticalInsets)
        guard !text.isEmpty else { return minHeight }

        let constraint = CGSize(width: max(width, 1), height: .greatestFiniteMagnitude)
        let rect = (text as NSString).boundingRect(
            with: constraint,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let contentHeight = ceil(rect.height) + verticalInsets
        return min(max(contentHeight, minHeight), maxHeight)
    }
}

enum ComposerPasteLogger {
    private static let logger = makeLogger(tag: .chat)

    static func pasteInvoked(hasImages: Bool, itemCount: Int) {
        logger.debugInfo("[composer-paste] paste invoked hasImages=\(hasImages) items=\(itemCount)")
    }

    static func loadStarted(maxCount: Int, hasImages: Bool, providerCount: Int, types: String) {
        logger.debugInfo(
            "[composer-paste] load start max=\(maxCount) hasImages=\(hasImages) providers=\(providerCount) types=\(types)"
        )
    }

    static func loadFinished(count: Int, attempt: Int, usedFallbackImage: Bool, source: String) {
        logger.debugInfo(
            "[composer-paste] load done count=\(count) attempt=\(attempt) fallbackImage=\(usedFallbackImage) source=\(source)"
        )
    }

    static func loadEmptyAfterRetry(hasImages: Bool) {
        logger.warning("[composer-paste] load empty after retry hasImages=\(hasImages)")
    }
}
