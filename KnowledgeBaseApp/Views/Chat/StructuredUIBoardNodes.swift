import Charts
import SwiftUI

struct StructuredUIMetricNodeView: View {
    let node: KBStructuredUINode
    /// When true, use a more compact type scale (metric grids).
    var compact: Bool = false
    var onAppAction: ((KBAppAction, KBStructuredUINode) -> Void)? = nil

    private var isTappable: Bool {
        node.action != nil && onAppAction != nil
    }

    var body: some View {
        Group {
            if let action = node.action, let onAppAction {
                Button {
                    onAppAction(action, node)
                } label: {
                    metricContent
                }
                .buttonStyle(.plain)
            } else {
                metricContent
            }
        }
        .accessibilityAddTraits(isTappable ? .isButton : [])
    }

    private var metricContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let label = node.label, !label.isEmpty {
                    Text(label)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                if isTappable {
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            Text(StructuredUIMetricDisplay.value(from: node))
                .font((compact ? Font.title3 : Font.title2).weight(.semibold).monospacedDigit())
                .foregroundStyle(isTappable ? Color.accentColor : Color.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 10 : 12)
        .background(Color.secondary.opacity(isTappable ? 0.16 : 0.12))
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
                        let column = index < columns.count ? columns[index] : nil
                        Text(StructuredUITableDisplay.cell(row, at: index, column: column))
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

struct StructuredUIChartNodeView: View {
    let node: KBStructuredUINode
    var onAppAction: ((KBAppAction, KBStructuredUINode) -> Void)? = nil

    private var points: [(id: Int, label: String, display: String, value: Double)] {
        (node.series ?? []).enumerated().compactMap { index, point in
            guard let value = point.y else { return nil }
            let raw = point.x?.isEmpty == false ? (point.x ?? "") : "\(index + 1)"
            return (index, raw, StructuredUIChartDisplay.axisLabel(from: raw), value)
        }
    }

    private var tapAction: KBAppAction {
        node.action ?? .openChartDetail(chartId: node.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if let label = node.label, !label.isEmpty {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                }
                Spacer(minLength: 0)
                if onAppAction != nil, !points.isEmpty {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            if points.isEmpty {
                Text("—")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                chartBody
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onAppAction?(tapAction, node)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(node.label ?? "Chart")
        .accessibilityAddTraits(onAppAction != nil && !points.isEmpty ? .isButton : [])
    }

    private var chartBody: some View {
        Chart(points, id: \.id) { point in
            LineMark(
                x: .value("X", point.label),
                y: .value("Y", point.value)
            )
            .interpolationMethod(.catmullRom)
            AreaMark(
                x: .value("X", point.label),
                y: .value("Y", point.value)
            )
            .foregroundStyle(Color.accentColor.opacity(0.12))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(5, points.count))) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let raw = value.as(String.self) {
                        Text(StructuredUIChartDisplay.axisLabel(from: raw))
                    }
                }
            }
        }
        .frame(height: 160)
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Live elapsed stopwatch from an ISO-8601 ``value`` (or ``text`` snapshot fallback).
struct StructuredUITimerNodeView: View {
    let node: KBStructuredUINode
    var compact: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label = node.label, !label.isEmpty {
                Text(label)
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let start = StructuredUITimerDisplay.startDate(from: node) {
                TimelineView(.periodic(from: start, by: 1)) { context in
                    Text(StructuredUITimerDisplay.elapsedText(since: start, now: context.date))
                        .font((compact ? Font.title3 : Font.title2).weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            } else {
                Text(node.text?.isEmpty == false ? (node.text ?? "—") : "—")
                    .font((compact ? Font.title3 : Font.title2).weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 10 : 12)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(StructuredUITimerDisplay.accessibilityLabel(from: node))
    }
}

enum StructuredUITimerDisplay {
    static func startDate(from node: KBStructuredUINode) -> Date? {
        if let raw = node.value?.stringValue, let date = parseISO8601(raw) {
            return date
        }
        if let raw = node.text, let date = parseISO8601(raw) {
            return date
        }
        return nil
    }

    static func elapsedText(since start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func accessibilityLabel(from node: KBStructuredUINode) -> String {
        let label = node.label?.isEmpty == false ? (node.label ?? "") : "Timer"
        if let start = startDate(from: node) {
            return "\(label), \(elapsedText(since: start, now: Date()))"
        }
        if let text = node.text, !text.isEmpty {
            return "\(label), \(text)"
        }
        return label
    }

    static func parseISO8601(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: trimmed) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: trimmed) {
            return date
        }
        // Postgres sometimes yields "2026-09-29 15:00:00+00" without T.
        let normalized = trimmed
            .replacingOccurrences(of: " ", with: "T")
            .replacingOccurrences(of: "+00", with: "+00:00")
        if let date = plain.date(from: normalized) {
            return date
        }
        if let date = withFractional.date(from: normalized) {
            return date
        }
        return nil
    }
}
