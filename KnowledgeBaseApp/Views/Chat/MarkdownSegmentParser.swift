import Foundation

enum MarkdownListMarker: Equatable {
    case bullet
    case numbered(Int)
}

struct MarkdownListItem: Equatable {
    let indentLevel: Int
    let marker: MarkdownListMarker
    let text: String
}

enum MarkdownSegment: Equatable, Identifiable {
    case blank
    case horizontalRule
    case header(level: Int, line: String)
    case paragraph(String)
    case list([MarkdownListItem])
    case codeBlock(language: String?, code: String)
    case blockquote([String])

    var id: String {
        switch self {
        case .blank: return "blank"
        case .horizontalRule: return "hr"
        case .header(let level, let line): return "h\(level)-\(line.hashValue)"
        case .paragraph(let line): return "p-\(line.hashValue)"
        case .list(let items): return "list-\(items.count)-\(items.first?.text.hashValue ?? 0)"
        case .codeBlock(let lang, let code): return "code-\(lang ?? "")-\(code.hashValue)"
        case .blockquote(let lines): return "bq-\(lines.joined().hashValue)"
        }
    }
}

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

    static func isCodeFenceOpening(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("```") && t.count >= 3
    }

    static func isCodeFenceClosing(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces) == "```"
    }

    static func codeFenceLanguage(_ line: String) -> String? {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("```") else { return nil }
        let lang = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        return lang.isEmpty ? nil : lang
    }

    static func parseListItem(_ line: String) -> MarkdownListItem? {
        let leading = line.prefix(while: { $0 == " " }).count
        let indentLevel = leading / 2
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if let bullet = parseBullet(trimmed) {
            return MarkdownListItem(indentLevel: indentLevel, marker: .bullet, text: bullet)
        }
        if let (num, text) = parseNumbered(trimmed) {
            return MarkdownListItem(indentLevel: indentLevel, marker: .numbered(num), text: text)
        }
        return nil
    }

    private static func parseBullet(_ trimmed: String) -> String? {
        guard trimmed.count >= 2 else { return nil }
        let chars = Array(trimmed)
        let m = chars[0]
        guard m == "-" || m == "*" || m == "+" else { return nil }
        guard chars[1] == " " else { return nil }
        let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    private static func parseNumbered(_ trimmed: String) -> (Int, String)? {
        guard let dot = trimmed.firstIndex(of: ".") else { return nil }
        let numPart = trimmed[..<dot]
        guard let num = Int(numPart), num > 0 else { return nil }
        var after = String(trimmed[trimmed.index(after: dot)...])
        if after.first == " " { after.removeFirst() }
        let text = after.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : (num, text)
    }

    static func isBlockquoteLine(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix(">")
    }

    static func blockquoteContent(_ line: String) -> String {
        var t = line.trimmingCharacters(in: .whitespaces)
        guard t.first == ">" else { return line }
        t.removeFirst()
        if t.first == " " { t.removeFirst() }
        return t
    }
}

enum MarkdownSegmentParser {
    static func segments(from text: String) -> [MarkdownSegment] {
        let lines = text.components(separatedBy: "\n")
        var result: [MarkdownSegment] = []
        var index = 0

        while index < lines.count {
            let raw = lines[index]

            if raw.trimmingCharacters(in: .whitespaces).isEmpty {
                result.append(.blank)
                index += 1
                continue
            }

            if MarkdownLineParser.isCodeFenceOpening(raw) {
                let language = MarkdownLineParser.codeFenceLanguage(raw)
                index += 1
                var codeLines: [String] = []
                while index < lines.count, !MarkdownLineParser.isCodeFenceClosing(lines[index]) {
                    codeLines.append(lines[index])
                    index += 1
                }
                if index < lines.count { index += 1 }
                result.append(.codeBlock(language: language, code: codeLines.joined(separator: "\n")))
                continue
            }

            if let first = MarkdownLineParser.parseListItem(raw) {
                var items = [first]
                index += 1
                while index < lines.count, let next = MarkdownLineParser.parseListItem(lines[index]) {
                    items.append(next)
                    index += 1
                }
                result.append(.list(items))
                continue
            }

            if MarkdownLineParser.isBlockquoteLine(raw) {
                var quoteLines: [String] = []
                while index < lines.count, MarkdownLineParser.isBlockquoteLine(lines[index]) {
                    quoteLines.append(MarkdownLineParser.blockquoteContent(lines[index]))
                    index += 1
                }
                result.append(.blockquote(quoteLines))
                continue
            }

            if MarkdownLineParser.isThematicBreak(raw) {
                result.append(.horizontalRule)
                index += 1
                continue
            }

            let hashCount = raw.prefix(while: { $0 == "#" }).count
            if hashCount > 0, hashCount <= 6, raw.dropFirst(hashCount).first == " " {
                result.append(.header(level: hashCount, line: raw))
                index += 1
                continue
            }

            result.append(.paragraph(raw))
            index += 1
        }

        return result
    }
}
