import SwiftUI

struct MarkdownTableView: View {
    let header: [String]
    let rows: [[String]]

    private var columnCount: Int {
        max(header.count, rows.map(\.count).max() ?? 0)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(0 ..< columnCount, id: \.self) { col in
                        cellText(header[safe: col] ?? "", bold: true)
                            .frame(minWidth: 88, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.08))
                    }
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(0 ..< columnCount, id: \.self) { col in
                            cellText(row[safe: col] ?? "", bold: false)
                                .frame(minWidth: 88, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(rowIndex.isMultiple(of: 2)
                                    ? Color.clear
                                    : Color.primary.opacity(0.04))
                        }
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private func cellText(_ value: String, bold: Bool) -> some View {
        Text(MessageContentRenderer.inlineAttributedText(value))
            .font(bold ? .subheadline.weight(.semibold) : .subheadline)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
