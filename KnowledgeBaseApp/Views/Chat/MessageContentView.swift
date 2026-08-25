import SwiftUI
import UIKit

enum MessageContentRenderer {
    /// Full markdown block (headers, lists, bold, etc.).
    static func attributedText(for message: KBMessage) -> AttributedString {
        attributedText(from: sanitizedContent(message.content), format: message.resolvedContentFormat)
    }

    static func attributedText(from content: String, format: ContentFormat) -> AttributedString {
        let cleaned = sanitizedContent(content)
        guard !cleaned.isEmpty else { return AttributedString("") }

        switch format {
        case .markdown:
            return parseMarkdown(cleaned)
        case .html:
            return htmlToAttributed(cleaned) ?? AttributedString(cleaned)
        case .plain:
            return AttributedString(cleaned)
        }
    }

    private static func sanitizedContent(_ content: String) -> String {
        TerminalSanitizer.stripEscapeSequences(content)
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
        // WebKit HTML import often bakes in black Times text — invisible on dark chat backgrounds
        // and ignores SwiftUI `.font` / `.foregroundStyle`. Strip those so the bubble stays readable.
        let mutable = NSMutableAttributedString(attributedString: ns)
        let fullRange = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
            if attrs[.foregroundColor] != nil {
                mutable.removeAttribute(.foregroundColor, range: range)
            }
            if attrs[.backgroundColor] != nil {
                mutable.removeAttribute(.backgroundColor, range: range)
            }
            if attrs[.font] != nil {
                mutable.removeAttribute(.font, range: range)
            }
        }
        return AttributedString(mutable)
    }

    /// Markdown mislabeled as HTML (e.g. `<ul>` inside backticks) often renders poorly:
    /// WebKit may eat the tag and leave raw `##` / `**` markers, or collapse to near-empty.
    static func shouldFallbackHTMLToMarkdown(source: String, htmlRendered: AttributedString) -> Bool {
        let cleaned = sanitizedContent(source)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count > 40 else { return false }

        // Cursor replies are markdown; prefer the markdown pipeline whenever signals are clear.
        if looksLikeMarkdown(cleaned) {
            return true
        }

        let rendered = String(htmlRendered.characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Classic near-empty HTML render of substantial source.
        return rendered.count < min(80, cleaned.count / 4)
    }

    static func looksLikeMarkdown(_ source: String) -> Bool {
        if source.hasPrefix("#") || source.contains("\n#") { return true }
        if source.contains("**") { return true }
        if source.range(of: #"(?m)^\s*[-*+]\s+\S"#, options: .regularExpression) != nil {
            return true
        }
        if source.range(of: #"`<[^`]+>`"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }
}

struct MessageContentView: View {
    let message: KBMessage
    var contentOverride: String?

    private var text: String {
        let raw = contentOverride ?? message.content
        return TerminalSanitizer.stripEscapeSequences(raw)
    }

    private var format: ContentFormat {
        message.resolvedContentFormat
    }

    var body: some View {
        switch effectiveFormat {
        case .markdown:
            markdownBody
        case .plain:
            PlainTextBlockView(text: text)
        case .html:
            htmlBody
        }
    }

    private var effectiveFormat: ContentFormat {
        guard format == .html else { return format }
        if MessageContentRenderer.looksLikeMarkdown(text) {
            return .markdown
        }
        let htmlRendered = MessageContentRenderer.attributedText(from: text, format: .html)
        if MessageContentRenderer.shouldFallbackHTMLToMarkdown(source: text, htmlRendered: htmlRendered) {
            return .markdown
        }
        return .html
    }

    @ViewBuilder
    private var htmlBody: some View {
        let attributed = MessageContentRenderer.attributedText(from: text, format: .html)
        Text(attributed)
            .font(.body)
            .foregroundStyle(.primary)
            .textSelection(.enabled)
    }

    @ViewBuilder
    private var markdownBody: some View {
        let blocks = MarkdownBlockParser.blocks(from: text)
        if blocks.isEmpty {
            MarkdownTextBlockView(text: text)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .text(let chunk):
                        MarkdownTextBlockView(text: chunk)
                    case .table(let header, let rows):
                        MarkdownTableView(header: header, rows: rows)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
