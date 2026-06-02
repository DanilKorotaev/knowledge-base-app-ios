import SwiftUI

/// Shared table layout: fixed column width, wrapped text, equal row height via `Grid`.
struct MarkdownTableGrid: View {
    let header: [String]
    let rows: [[String]]
    let columnWidth: CGFloat
    var compactPadding = true

    private var columnCount: Int {
        max(header.count, rows.map(\.count).max() ?? 0)
    }

    private var cellPaddingH: CGFloat { compactPadding ? 6 : 8 }
    private var cellPaddingV: CGFloat { compactPadding ? 4 : 6 }

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(0 ..< columnCount, id: \.self) { col in
                    cell(header[safe: col] ?? "", bold: true, background: Color.primary.opacity(0.08))
                }
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                GridRow {
                    ForEach(0 ..< columnCount, id: \.self) { col in
                        cell(
                            row[safe: col] ?? "",
                            bold: false,
                            background: index.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.04)
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(_ value: String, bold: Bool, background: Color) -> some View {
        Text(MessageContentRenderer.inlineAttributedText(value))
            .font(bold ? .subheadline.weight(.semibold) : .subheadline)
            .multilineTextAlignment(.leading)
            .frame(width: columnWidth, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, cellPaddingH)
            .padding(.vertical, cellPaddingV)
            .background(background)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1)
            }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
