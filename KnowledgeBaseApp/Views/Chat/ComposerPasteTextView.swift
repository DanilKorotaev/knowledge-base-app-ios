import SwiftUI
import UIKit

/// Growing composer text view that turns image paste into attachments instead of ignoring them.
struct ComposerPasteTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isEnabled: Bool
    /// 3 when file/image attachments are present (historical TextField `lineLimit(3...8)`), else 1.
    var minimumLineCount: Int = 1
    var onPasteImages: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PasteAwareTextView {
        let textView = PasteAwareTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        // Extra bottom inset so the last line’s descenders are not clipped by SwiftUI/UIKit.
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.isScrollEnabled = false
        textView.clipsToBounds = true
        textView.keyboardDismissMode = .interactive
        textView.minimumLineCount = minimumLineCount
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
        if textView.minimumLineCount != minimumLineCount {
            textView.minimumLineCount = minimumLineCount
        }
        if textView.text != text {
            textView.text = text
            textView.invalidateIntrinsicContentSize()
        }
        context.coordinator.placeholderLabel?.text = placeholder
        context.coordinator.updatePlaceholderVisibility(in: textView)
    }

    /// Prefer explicit height from content — ignore tall SwiftUI height proposals that used to stretch the field.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PasteAwareTextView, context: Context) -> CGSize? {
        let fallbackWidth = uiView.bounds.width > 1
            ? uiView.bounds.width
            : (UIScreen.main.bounds.width - 48)
        let width = proposal.width ?? fallbackWidth
        let height = uiView.preferredHeight(forWidth: width)
        return CGSize(width: width, height: height)
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
            textView.invalidateIntrinsicContentSize()
        }

        func updatePlaceholderVisibility(in textView: UITextView) {
            placeholderLabel?.isHidden = !(textView.text ?? "").isEmpty
        }
    }
}

final class PasteAwareTextView: UITextView {
    var onPasteImages: (() -> Void)?
    var minimumLineCount: Int = 1 {
        didSet {
            if oldValue != minimumLineCount {
                invalidateIntrinsicContentSize()
            }
        }
    }

    private var lineHeight: CGFloat {
        (font ?? UIFont.preferredFont(forTextStyle: .body)).lineHeight
    }

    private var minHeight: CGFloat {
        ceil(lineHeight * CGFloat(max(1, minimumLineCount)) + textContainerInset.top + textContainerInset.bottom)
    }

    /// ~8 lines of body text — matches previous TextField `lineLimit(…8)`.
    private var maxHeight: CGFloat {
        ceil(lineHeight * 8 + textContainerInset.top + textContainerInset.bottom)
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 1
            ? bounds.width
            : (superview?.bounds.width ?? UIScreen.main.bounds.width - 48)
        return CGSize(width: UIView.noIntrinsicMetric, height: preferredHeight(forWidth: width))
    }

    /// Height for SwiftUI / intrinsic sizing. Uses layoutManager so scroll-enabled state cannot collapse us to 1 line.
    func preferredHeight(forWidth width: CGFloat) -> CGFloat {
        let content = measuredContentHeight(width: max(width, 1))
        return min(max(content, minHeight), maxHeight)
    }

    private func measuredContentHeight(width: CGFloat) -> CGFloat {
        let insetWidth = width - textContainerInset.left - textContainerInset.right
        let previousSize = textContainer.size
        textContainer.size = CGSize(width: max(insetWidth, 1), height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer)
        textContainer.size = previousSize
        // +1pt: last glyph line otherwise sits under the clip edge after bounce settle.
        return ceil(used.height + textContainerInset.top + textContainerInset.bottom + 1)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        clipsToBounds = true
        let width = bounds.width
        guard width > 1 else { return }
        let contentHeight = measuredContentHeight(width: width)
        let shouldScroll = contentHeight > maxHeight + 0.5
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
            ComposerPasteLogger.pasteInvoked(
                hasImages: true,
                itemCount: UIPasteboard.general.numberOfItems
            )
            // Attach images; do not insert binary/image representations into the text field.
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

enum ComposerPasteLogger {
    private static let logger = makeLogger(tag: .chat)

    static func pasteInvoked(hasImages: Bool, itemCount: Int) {
        logger.debugInfo("[composer-paste] paste invoked hasImages=\(hasImages) items=\(itemCount)")
    }

    static func loadStarted(maxCount: Int, hasImages: Bool, providerCount: Int) {
        logger.debugInfo(
            "[composer-paste] load start max=\(maxCount) hasImages=\(hasImages) providers=\(providerCount)"
        )
    }

    static func loadFinished(count: Int, attempt: Int, usedFallbackImage: Bool) {
        logger.debugInfo(
            "[composer-paste] load done count=\(count) attempt=\(attempt) fallbackImage=\(usedFallbackImage)"
        )
    }

    static func loadEmptyAfterRetry(hasImages: Bool) {
        logger.warning("[composer-paste] load empty after retry hasImages=\(hasImages)")
    }
}
