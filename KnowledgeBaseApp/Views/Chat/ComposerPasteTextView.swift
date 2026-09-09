import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Paste/drop-aware composer text view. Height is owned by SwiftUI (`.frame(height:)`).
struct ComposerPasteTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isEnabled: Bool
    /// Returns `true` when at least one image attachment was added.
    var onPasteImages: () async -> Bool
    /// Preferred path: `UIDropSession.loadObjects(UIImage)` (no system Import HUD).
    var onDropUIImages: ([UIImage]) -> Void
    /// Fallback when session has only providers (e.g. file URL) without a ready UIImage.
    var onDropProviders: ([NSItemProvider]) -> Void
    var onPasteImagesFailed: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PasteAwareTextView {
        let textView = PasteAwareTextView()
        textView.delegate = context.coordinator
        textView.textDropDelegate = context.coordinator
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
        textView.addInteraction(UIDropInteraction(delegate: context.coordinator))
        textView.onPasteImages = {
            await context.coordinator.parent.onPasteImages()
        }
        textView.onPasteImagesFailed = {
            context.coordinator.parent.onPasteImagesFailed()
        }
        context.coordinator.placeholderLabel = makePlaceholderLabel(in: textView)
        context.coordinator.updatePlaceholderVisibility(in: textView)
        return textView
    }

    func updateUIView(_ textView: PasteAwareTextView, context: Context) {
        context.coordinator.parent = self
        textView.onPasteImages = {
            await context.coordinator.parent.onPasteImages()
        }
        textView.onPasteImagesFailed = {
            context.coordinator.parent.onPasteImagesFailed()
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

    final class Coordinator: NSObject, UITextViewDelegate, UITextDropDelegate, UIDropInteractionDelegate {
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

        // MARK: UITextDropDelegate — keep images out of attributed text when focused

        func textDroppableView(
            _ textDroppableView: UIView & UITextDroppable,
            proposalForDrop drop: UITextDropRequest
        ) -> UITextDropProposal {
            if PasteAwareTextView.sessionHasImportableImage(drop.dropSession) {
                // Forbid UITextView's default NSTextAttachment insertion; UIDropInteraction handles copy.
                return UITextDropProposal(operation: .forbidden)
            }
            return UITextDropProposal(operation: .copy)
        }

        // MARK: UIDropInteractionDelegate — works while UITextView is first responder

        func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
            PasteAwareTextView.sessionHasImportableImage(session)
        }

        func dropInteraction(
            _ interaction: UIDropInteraction,
            sessionDidUpdate session: UIDropSession
        ) -> UIDropProposal {
            UIDropProposal(operation: .copy)
        }

        func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
            // Prefer session.loadObjects(UIImage) — in-memory screenshot/thumb drops.
            // loadDataRepresentation on the same providers triggers the system
            // "Import N objects" progress sheet and often hangs / returns nil.
            let providers = session.items.map(\.itemProvider)
            session.loadObjects(ofClass: UIImage.self) { [weak self] objects in
                let images = objects.compactMap { $0 as? UIImage }
                DispatchQueue.main.async {
                    guard let self else { return }
                    if !images.isEmpty {
                        self.parent.onDropUIImages(images)
                    } else {
                        self.parent.onDropProviders(providers)
                    }
                }
            }
        }
    }
}

final class PasteAwareTextView: UITextView {
    var onPasteImages: (() async -> Bool)?
    var onPasteImagesFailed: (() -> Void)?

    private static let imageTypeIdentifiers: [String] = [
        UTType.image.identifier,
        UTType.jpeg.identifier,
        UTType.png.identifier,
        UTType.heic.identifier,
        UTType.heif.identifier,
        UTType.gif.identifier,
        UTType.webP.identifier,
    ]

    static func sessionHasImportableImage(_ session: UIDropSession) -> Bool {
        if session.hasItemsConforming(toTypeIdentifiers: imageTypeIdentifiers) {
            return true
        }
        return session.hasItemsConforming(toTypeIdentifiers: [UTType.fileURL.identifier])
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)), ClipboardMediaImporter.pasteboardHasImages {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }

    override func paste(_ sender: Any?) {
        let claimsImages = ClipboardMediaImporter.pasteboardHasImages
        ComposerPasteLogger.pasteInvoked(
            hasImages: claimsImages,
            itemCount: UIPasteboard.general.numberOfItems
        )
        guard claimsImages, let onPasteImages else {
            super.paste(sender)
            return
        }

        Task { @MainActor in
            let attached = await onPasteImages()
            if attached { return }

            // Clipboard often advertises an image UTI alongside plain text (or a stale image).
            // Prefer inserting text over a false-positive error when bytes never materialize.
            if let string = UIPasteboard.general.string, !string.isEmpty {
                let selected = selectedRange
                if let range = Range(selected, in: text ?? "") {
                    text?.replaceSubrange(range, with: string)
                } else {
                    insertText(string)
                }
                delegate?.textViewDidChange?(self)
                return
            }

            if ClipboardMediaImporter.pasteboardHasImages {
                onPasteImagesFailed?()
            }
        }
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

    static func dropPerformed(itemCount: Int, focused: Bool) {
        logger.debugInfo("[composer-paste] drop performed items=\(itemCount) textFocused=\(focused)")
    }

    static func dropIgnoredDuplicate(source: String) {
        logger.debugInfo("[composer-paste] drop ignored duplicate source=\(source)")
    }

    static func dropProviders(count: Int, types: String) {
        logger.debugInfo("[composer-paste] drop providers=\(count) types=\(types)")
    }

    static func dropLoadFinished(count: Int, attempt: Int) {
        logger.debugInfo("[composer-paste] drop load done count=\(count) attempt=\(attempt)")
    }
}
