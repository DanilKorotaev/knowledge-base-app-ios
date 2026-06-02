import SwiftUI

/// Renders markdown-ish text line-by-line so `\n` from the server are preserved.
struct MarkdownTextBlockView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(displayLines.enumerated()), id: \.offset) { _, item in
                switch item {
                case .blank:
                    Color.clear.frame(height: 4)
                case .header(let level, let line):
                    Text(MessageContentRenderer.parseMarkdown(line))
                        .font(headerFont(level))
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .line(let line):
                    Text(MessageContentRenderer.inlineAttributedText(line))
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .textSelection(.enabled)
    }

    private enum DisplayLine {
        case blank
        case header(Int, String)
        case line(String)
    }

    private func displayLines(from source: String) -> [DisplayLine] {
        source.components(separatedBy: "\n").map { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return .blank }
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .textSelection(.enabled)
    }
}
