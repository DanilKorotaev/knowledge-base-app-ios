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

    static func cell(_ row: [String], at index: Int) -> String {
        guard index < row.count else { return "" }
        return row[index]
    }

    /// Auto horizontal scroll when column count exceeds this (unless JSON overrides).
    static let autoScrollColumnThreshold = 3

    static func allowsHorizontalScroll(scrollHorizontal: Bool?, columnCount: Int) -> Bool {
        if let scrollHorizontal { return scrollHorizontal }
        return columnCount > autoScrollColumnThreshold
    }
}
