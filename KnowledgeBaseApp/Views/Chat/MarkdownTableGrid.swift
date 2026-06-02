import SwiftUI

/// Shared table layout: fixed column width, wrapped text, aligned grid borders.
struct MarkdownTableGrid: View {
    let header: [String]
    let rows: [[String]]
    let columnWidth: CGFloat
    var compactPadding = true

    private var columnCount: Int {
        max(header.count, rows.map(\.count).max() ?? 0)
    }

    private var cellPaddingH: CGFloat { compactPadding ? 8 : 10 }
    private var cellPaddingV: CGFloat { compactPadding ? 6 : 8 }

    private var borderColor: Color { Color.primary.opacity(0.14) }
    private var headerFill: Color { Color(.secondarySystemFill) }
    private var zebraFill: Color { Color.primary.opacity(0.035) }

    var body: some View {
        VStack(spacing: 0) {
            rowView(cells: header, bold: true, fill: headerFill, drawBottomBorder: true)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, cells in
                rowView(
                    cells: cells,
                    bold: false,
                    fill: index.isMultiple(of: 2) ? Color.clear : zebraFill,
                    drawBottomBorder: index < rows.count - 1
                )
            }
        }
    }

    @ViewBuilder
    private func rowView(cells: [String], bold: Bool, fill: Color, drawBottomBorder: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0 ..< columnCount, id: \.self) { col in
                if col > 0 {
                    Rectangle()
                        .fill(borderColor)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
                cellText(cells[safe: col] ?? "", bold: bold)
                    .padding(.horizontal, cellPaddingH)
                    .padding(.vertical, cellPaddingV)
                    .frame(width: columnWidth, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .background(fill)
        .overlay(alignment: .bottom) {
            if drawBottomBorder {
                Rectangle()
                    .fill(borderColor)
                    .frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private func cellText(_ value: String, bold: Bool) -> some View {
        Text(MessageContentRenderer.inlineAttributedText(value))
            .font(bold ? .subheadline.weight(.semibold) : .subheadline)
            .multilineTextAlignment(.leading)
            .foregroundStyle(.primary)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
