import SwiftUI

enum MessageContentRenderer {
    static func attributedText(for message: KBMessage) -> AttributedString {
        let format = message.resolvedContentFormat
        let content = message.content
        guard !content.isEmpty else { return AttributedString("") }

        switch format {
        case .markdown:
            if let parsed = try? AttributedString(
                markdown: content,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) {
                return parsed
            }
            if let parsed = try? AttributedString(markdown: content) {
                return parsed
            }
            return AttributedString(content)
        case .html:
            return htmlToAttributed(content) ?? AttributedString(content)
        case .plain:
            return AttributedString(content)
        }
    }

    private static func htmlToAttributed(_ html: String) -> AttributedString? {
        guard let data = html.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        guard let ns = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }
        return AttributedString(ns)
    }
}

struct MessageContentView: View {
    let message: KBMessage

    var body: some View {
        Text(MessageContentRenderer.attributedText(for: message))
            .font(.body)
            .textSelection(.enabled)
    }
}
