import SwiftUI

enum MessageContentRenderer {
    /// Full markdown block (headers, lists, bold, etc.).
    static func attributedText(for message: KBMessage) -> AttributedString {
        attributedText(from: message.content, format: message.resolvedContentFormat)
    }

    static func attributedText(from content: String, format: ContentFormat) -> AttributedString {
        guard !content.isEmpty else { return AttributedString("") }

        switch format {
        case .markdown:
            return parseMarkdown(content)
        case .html:
            return htmlToAttributed(content) ?? AttributedString(content)
        case .plain:
            return AttributedString(content)
        }
    }

    /// Inline markdown only (bold, code) — preserves structure when rendered line-by-line.
    static func inlineAttributedText(_ content: String) -> AttributedString {
        guard !content.isEmpty else { return AttributedString("") }
        if let parsed = try? AttributedString(
            markdown: content,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return parsed
        }
        return AttributedString(content)
    }

    static func parseMarkdown(_ content: String) -> AttributedString {
        if let parsed = try? AttributedString(
            markdown: content,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) {
            return parsed
        }
        if let parsed = try? AttributedString(markdown: content) {
            return parsed
        }
        return AttributedString(content)
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
    var contentOverride: String?

    private var text: String {
        contentOverride ?? message.content
    }

    private var format: ContentFormat {
        message.resolvedContentFormat
    }

    var body: some View {
        switch format {
        case .markdown:
            markdownBody
        case .plain:
            PlainTextBlockView(text: text)
        case .html:
            Text(MessageContentRenderer.attributedText(from: text, format: format))
                .font(.body)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var markdownBody: some View {
        let blocks = MarkdownBlockParser.blocks(from: text)
        if blocks.isEmpty {
            MarkdownTextBlockView(text: text)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(blocks) { block in
                    switch block {
                    case .text(let chunk):
                        MarkdownTextBlockView(text: chunk)
                    case .table(let header, let rows):
                        MarkdownTableView(header: header, rows: rows)
                    }
                }
            }
        }
    }
}
