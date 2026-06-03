import SwiftUI

/// Renders markdown text blocks: lists, code, quotes, headers, preserved line breaks.
struct MarkdownTextBlockView: View {
    let text: String

    private var segments: [MarkdownSegment] {
        MarkdownSegmentParser.segments(from: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(segments) { segment in
                segmentView(segment)
            }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func segmentView(_ segment: MarkdownSegment) -> some View {
        switch segment {
        case .blank:
            Color.clear.frame(height: 4)
        case .horizontalRule:
            Rectangle()
                .fill(Color.primary.opacity(0.15))
                .frame(height: 1)
                .padding(.vertical, 4)
        case .header(let level, let line):
            Text(MessageContentRenderer.parseMarkdown(line))
                .font(headerFont(level))
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .paragraph(let line):
            Text(MessageContentRenderer.inlineAttributedText(line))
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .list(let items):
            listView(items)
        case .codeBlock(let language, let code):
            MarkdownCodeBlockView(language: language, code: code)
        case .blockquote(let lines):
            blockquoteView(lines)
        }
    }

    @ViewBuilder
    private func listView(_ items: [MarkdownListItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Text(listMarkerLabel(item.marker))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 22, alignment: .trailing)
                    Text(MessageContentRenderer.inlineAttributedText(item.text))
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, CGFloat(item.indentLevel) * 16)
            }
        }
    }

    @ViewBuilder
    private func blockquoteView(_ lines: [String]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.accentColor.opacity(0.55))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(MessageContentRenderer.inlineAttributedText(line))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.leading, 10)
            .padding(.vertical, 4)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func listMarkerLabel(_ marker: MarkdownListMarker) -> String {
        switch marker {
        case .bullet: return "•"
        case .numbered(let n): return "\(n)."
        }
    }

    private func headerFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title2
        case 2: return .title3
        case 3: return .headline
        default: return .subheadline
        }
    }
}

/// Plain text with preserved line breaks.
struct PlainTextBlockView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    Color.clear.frame(height: 4)
                } else {
                    Text(line)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .textSelection(.enabled)
    }
}
