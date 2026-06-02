import Foundation

enum MarkdownBlock: Equatable, Identifiable {
    case text(String)
    case table(header: [String], rows: [[String]])

    var id: String {
        switch self {
        case .text(let string):
            return "t-\(string.hashValue)"
        case .table(let header, let rows):
            return "tbl-\(header.hashValue)-\(rows.count)"
        }
    }
}

enum MarkdownBlockParser {
    /// Splits markdown into text runs and GFM-style tables.
    static func blocks(from markdown: String) -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: "\n")
        var result: [MarkdownBlock] = []
        var textBuffer: [String] = []
        var index = 0

        func flushText() {
            guard !textBuffer.isEmpty else { return }
            let chunk = textBuffer.joined(separator: "\n")
            textBuffer.removeAll()
            if !chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(.text(chunk))
            }
        }

        while index < lines.count {
            let line = lines[index]
            if isTableRow(line), index + 1 < lines.count, isSeparatorRow(lines[index + 1]) {
                flushText()
                let header = parseCells(line)
                index += 2
                var rows: [[String]] = []
                while index < lines.count, isTableRow(lines[index]), !isSeparatorRow(lines[index]) {
                    rows.append(parseCells(lines[index]))
                    index += 1
                }
                if !header.isEmpty {
                    result.append(.table(header: header, rows: rows))
                }
                continue
            }
            textBuffer.append(line)
            index += 1
        }
        flushText()
        return result
    }

    private static func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("|") && trimmed.filter({ $0 == "|" }).count >= 2
    }

    private static func isSeparatorRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return false }
        return trimmed.replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespaces)
            .isEmpty
    }

    private static func parseCells(_ line: String) -> [String] {
        line
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
