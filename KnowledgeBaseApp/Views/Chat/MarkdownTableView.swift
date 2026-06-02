import SwiftUI

struct MarkdownTableView: View {
    let header: [String]
    let rows: [[String]]

    private let maxColumnWidth: CGFloat = 132
    private let cellPaddingH: CGFloat = 10
    private let cellPaddingV: CGFloat = 8

    private var columnCount: Int {
        max(header.count, rows.map(\.count).max() ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowCells(header, bold: true, background: Color.primary.opacity(0.08))
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                rowCells(row, bold: false, background: index.isMultiple(of: 2)
                    ? Color.clear
                    : Color.primary.opacity(0.04))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func rowCells(_ cells: [String], bold: Bool, background: Color) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0 ..< columnCount, id: \.self) { col in
                cellText(cells[safe: col] ?? "", bold: bold)
                    .frame(maxWidth: maxColumnWidth, alignment: .topLeading)
                    .padding(.horizontal, cellPaddingH)
                    .padding(.vertical, cellPaddingV)
                    .background(background)
                if col < columnCount - 1 {
                    Divider()
                }
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
