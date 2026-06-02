import SwiftUI

enum MarkdownLineParser {
    /// GFM thematic break: `---`, `***`, `___` (spaces allowed between chars).
    static func isThematicBreak(_ line: String) -> Bool {
        let compact = line
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3 else { return false }
        guard let marker = compact.first, marker == "-" || marker == "*" || marker == "_" else { return false }
        return compact.allSatisfy { $0 == marker }
    }
}

/// Renders markdown-ish text line-by-line so `\n` from the server are preserved.
struct MarkdownTextBlockView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(displayLines.enumerated()), id: \.offset) { _, item in
                switch item {
                case .blank:
                    Color.clear.frame(height: 4)
                case .horizontalRule:
                    Rectangle()
                        .fill(Color.primary.opacity(0.15))
                        .frame(height: 1)
                        .padding(.vertical, 6)
                case .header(let level, let line):
                    Text(MessageContentRenderer.parseMarkdown(line))
                        .font(headerFont(level))
                        .fontWeight(.semibold)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .line(let line):
                    Text(MessageContentRenderer.inlineAttributedText(line))
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .textSelection(.enabled)
    }

    private enum DisplayLine {
        case blank
        case horizontalRule
        case header(Int, String)
        case line(String)
    }

    private func displayLines(from source: String) -> [DisplayLine] {
        source.components(separatedBy: "\n").map { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return .blank }
            if MarkdownLineParser.isThematicBreak(raw) { return .horizontalRule }
            let hashCount = raw.prefix(while: { $0 == "#" }).count
            if hashCount > 0, hashCount <= 6, raw.dropFirst(hashCount).first == " " {
                return .header(hashCount, raw)
            }
            return .line(raw)
        }
    }

    private var displayLines: [DisplayLine] {
        displayLines(from: text)
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
