import Charts
import SwiftUI

struct StructuredUIChartDetailPoint: Identifiable, Hashable {
    let id: Int
    let rawLabel: String
    let displayLabel: String
    let date: Date?
    let value: Double
}

struct StructuredUIChartDetailView: View {
    let title: String
    let points: [StructuredUIChartDetailPoint]

    @State private var selectedId: Int?
    @Environment(\.dismiss) private var dismiss

    private var selectedPoint: StructuredUIChartDetailPoint? {
        guard let selectedId else { return nil }
        return points.first { $0.id == selectedId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            selectionHeader
            if points.isEmpty {
                ContentUnavailableView("—", systemImage: "chart.xyaxis.line")
            } else {
                chart
            }
            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.close") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private var selectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let selectedPoint {
                Text(selectedPoint.displayLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(StructuredUIChartDisplay.formatValue(selectedPoint.value))
                    .font(.title.weight(.semibold).monospacedDigit())
            } else {
                Text("boards.chart.scrub_hint")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let last = points.last {
                    Text(StructuredUIChartDisplay.formatValue(last.value))
                        .font(.title.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var chart: some View {
        Chart(points) { point in
            LineMark(
                x: .value("X", point.rawLabel),
                y: .value("Y", point.value)
            )
            .interpolationMethod(.catmullRom)
            AreaMark(
                x: .value("X", point.rawLabel),
                y: .value("Y", point.value)
            )
            .foregroundStyle(Color.accentColor.opacity(0.12))
            .interpolationMethod(.catmullRom)
            if selectedId == point.id {
                RuleMark(x: .value("X", point.rawLabel))
                    .foregroundStyle(Color.secondary.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                PointMark(
                    x: .value("X", point.rawLabel),
                    y: .value("Y", point.value)
                )
                .symbolSize(64)
                .foregroundStyle(Color.accentColor)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(6, points.count))) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let raw = value.as(String.self) {
                        Text(StructuredUIChartDisplay.axisLabel(from: raw))
                    }
                }
            }
        }
        .chartXSelection(value: Binding(
            get: {
                guard let selectedId,
                      let point = points.first(where: { $0.id == selectedId })
                else { return nil as String? }
                return point.rawLabel
            },
            set: { raw in
                guard let raw else {
                    selectedId = nil
                    return
                }
                selectedId = points.first(where: { $0.rawLabel == raw })?.id
            }
        ))
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleDomainLength)
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .padding(.vertical, 8)
    }

    private var visibleDomainLength: Int {
        max(7, min(21, points.count))
    }

    static func points(from node: KBStructuredUINode) -> [StructuredUIChartDetailPoint] {
        (node.series ?? []).enumerated().compactMap { index, point in
            guard let value = point.y else { return nil }
            let raw = point.x?.isEmpty == false ? (point.x ?? "") : "\(index + 1)"
            return StructuredUIChartDetailPoint(
                id: index,
                rawLabel: raw,
                displayLabel: StructuredUIChartDisplay.detailLabel(from: raw),
                date: StructuredUIChartDisplay.parseDate(raw),
                value: value
            )
        }
    }
}

enum StructuredUIChartDisplay {
    private static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let axisDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return f
    }()

    private static let detailDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("dMMMyyyy")
        return f
    }()

    private static let valueFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = .autoupdatingCurrent
        f.numberStyle = .decimal
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        return f
    }()

    static func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return nil }
        return isoDay.date(from: String(trimmed.prefix(10)))
    }

    static func axisLabel(from raw: String) -> String {
        if let date = parseDate(raw) {
            return axisDay.string(from: date)
        }
        return raw
    }

    static func detailLabel(from raw: String) -> String {
        if let date = parseDate(raw) {
            return detailDay.string(from: date)
        }
        return raw
    }

    static func formatValue(_ value: Double) -> String {
        valueFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
