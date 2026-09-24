import SwiftUI

struct StructuredUIMetricNodeView: View {
    let node: KBStructuredUINode
    /// When true, use a more compact type scale (metric grids).
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label = node.label, !label.isEmpty {
                Text(label)
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            Text(StructuredUIMetricDisplay.value(from: node))
                .font((compact ? Font.title3 : Font.title2).weight(.semibold).monospacedDigit())
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 10 : 12)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(StructuredUIMetricDisplay.accessibilityLabel(from: node))
    }
}

/// Wraps metric children in a 2-column grid so KPI values stay readable.
struct StructuredUIMetricsGridView<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: spacing),
            GridItem(.flexible(), spacing: spacing),
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StructuredUITableNodeView: View {
    let node: KBStructuredUINode

    private var columns: [KBStructuredUITableColumn] {
        node.columns ?? []
    }

    private var rows: [[String]] {
        node.rows ?? []
    }

    /// Horizontal pan only when the server asks (`scroll_horizontal`) or the table is wide.
    private var allowsHorizontalScroll: Bool {
        StructuredUITableDisplay.allowsHorizontalScroll(
            scrollHorizontal: node.scrollHorizontal,
            columnCount: StructuredUITableDisplay.columnCount(columns: columns, rows: rows)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = node.label, !label.isEmpty {
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            if columns.isEmpty, rows.isEmpty {
                Text("—")
                    .foregroundStyle(.secondary)
            } else if allowsHorizontalScroll {
                ScrollView(.horizontal, showsIndicators: false) {
                    tableGrid(flexible: false)
                }
            } else {
                tableGrid(flexible: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(node.label ?? "Table")
    }

    @ViewBuilder
    private func tableGrid(flexible: Bool) -> some View {
        let count = StructuredUITableDisplay.columnCount(columns: columns, rows: rows)
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            if !columns.isEmpty {
                GridRow {
                    ForEach(columns, id: \.id) { column in
                        Text(column.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(
                                minWidth: flexible ? nil : 72,
                                maxWidth: flexible ? .infinity : nil,
                                alignment: .leading
                            )
                    }
                    if flexible, columns.count < count {
                        ForEach(0..<(count - columns.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
                Divider()
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(0..<count, id: \.self) { index in
                        Text(StructuredUITableDisplay.cell(row, at: index))
                            .font(.subheadline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .frame(
                                minWidth: flexible ? nil : 72,
                                maxWidth: flexible ? .infinity : nil,
                                alignment: .leading
                            )
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
