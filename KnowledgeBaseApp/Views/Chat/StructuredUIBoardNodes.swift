import SwiftUI

struct StructuredUIMetricNodeView: View {
    let node: KBStructuredUINode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label = node.label, !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(StructuredUIMetricDisplay.value(from: node))
                .font(.title2.weight(.semibold).monospacedDigit())
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(StructuredUIMetricDisplay.accessibilityLabel(from: node))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = node.label, !label.isEmpty {
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            if columns.isEmpty, rows.isEmpty {
                Text("—")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        if !columns.isEmpty {
                            GridRow {
                                ForEach(columns, id: \.id) { column in
                                    Text(column.label)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(minWidth: 72, alignment: .leading)
                                }
                            }
                            Divider()
                        }
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            GridRow {
                                ForEach(0..<StructuredUITableDisplay.columnCount(columns: columns, rows: rows), id: \.self) { index in
                                    Text(StructuredUITableDisplay.cell(row, at: index))
                                        .font(.subheadline)
                                        .frame(minWidth: 72, alignment: .leading)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(node.label ?? "Table")
    }
}
