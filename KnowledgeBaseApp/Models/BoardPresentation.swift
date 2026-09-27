import Foundation

/// Pure helpers for board list rows (keeps SwiftUI views thin and testable).
enum BoardListPresentation {
    static func title(for board: KBBoard) -> String {
        board.listCell?.title ?? board.title
    }

    static func subtitle(for board: KBBoard) -> String? {
        let value = board.listCell?.subtitle ?? board.subtitle
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    static func statusTone(_ tone: String?) -> BoardListStatusTone {
        switch tone {
        case "ok", "success":
            return .ok
        case "warn", "warning":
            return .warn
        case "error":
            return .error
        default:
            return .info
        }
    }
}

enum BoardListStatusTone: Equatable, Sendable {
    case ok
    case warn
    case error
    case info
}

enum StructuredUIMetricDisplay {
    static func value(from node: KBStructuredUINode) -> String {
        if let text = node.text, !text.isEmpty { return text }
        if let value = node.value {
            switch value {
            case .string(let s):
                return s
            case .number(let n):
                if n.rounded() == n { return String(Int(n.rounded())) }
                return String(format: "%.1f", n)
            case .bool(let b):
                return b ? "true" : "false"
            case .strings(let list):
                return list.joined(separator: ", ")
            }
        }
        return "—"
    }

    static func accessibilityLabel(from node: KBStructuredUINode) -> String {
        let label = node.label ?? ""
        let display = value(from: node)
        if label.isEmpty { return display }
        return "\(label): \(display)"
    }
}

enum StructuredUITableDisplay {
    static func columnCount(columns: [KBStructuredUITableColumn], rows: [[String]]) -> Int {
        max(columns.count, rows.map(\.count).max() ?? 0)
    }

    static func cell(
        _ row: [String],
        at index: Int,
        column: KBStructuredUITableColumn? = nil
    ) -> String {
        guard index < row.count else { return "" }
        let raw = row[index]
        if shouldFormatAsDate(raw, column: column) {
            return formatISODate(raw) ?? raw
        }
        return raw
    }

    /// Auto horizontal scroll when column count exceeds this (unless JSON overrides).
    static let autoScrollColumnThreshold = 3

    static func allowsHorizontalScroll(scrollHorizontal: Bool?, columnCount: Int) -> Bool {
        if let scrollHorizontal { return scrollHorizontal }
        return columnCount > autoScrollColumnThreshold
    }

    private static func shouldFormatAsDate(_ raw: String, column: KBStructuredUITableColumn?) -> Bool {
        if column?.id == "date" { return true }
        return isoDayRegex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) != nil
            && raw.count == 10
    }

    private static let isoDayRegex = try! NSRegularExpression(pattern: #"^\d{4}-\d{2}-\d{2}$"#)

    private static func formatISODate(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return nil }
        let day = String(trimmed.prefix(10))
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: day) else { return nil }
        let display = DateFormatter()
        display.locale = AppLanguageStore.shared.resolvedLocale
        display.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return display.string(from: date)
    }
}
