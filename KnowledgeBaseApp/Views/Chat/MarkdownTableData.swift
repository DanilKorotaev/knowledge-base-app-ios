import Foundation

struct MarkdownTableData: Identifiable, Equatable {
    let id = UUID()
    let header: [String]
    let rows: [[String]]
}
