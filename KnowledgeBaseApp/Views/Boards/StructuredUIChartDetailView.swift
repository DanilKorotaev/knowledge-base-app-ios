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

    @State private var selectedDate: Date?
    @State private var scrollPosition: Date = .now
    @State private var visibleDays: Double = 30
    @State private var magnifyBaseDays: Double?
    @Environment(\.dismiss) private var dismiss

    private var datedPoints: [(date: Date, value: Double, displayLabel: String)] {
        points.compactMap { point in
            guard let date = point.date else { return nil }
            return (date, point.value, point.displayLabel)
        }
    }

    private var usesDates: Bool {
        datedPoints.count >= 2
    }

    private var fullXDomain: ClosedRange<Date>? {
        guard let first = datedPoints.first?.date, let last = datedPoints.last?.date else { return nil }
        return first <= last ? first...last : last...first
    }

    private var visibleDuration: TimeInterval {
        max(visibleDays, 3) * 24 * 60 * 60
    }

    private var selectedPoint: StructuredUIChartDetailPoint? {
        if usesDates, let selectedDate {
            return points.min(by: { lhs, rhs in
                let ld = abs((lhs.date ?? .distantPast).timeIntervalSince(selectedDate))
                let rd = abs((rhs.date ?? .distantPast).timeIntervalSince(selectedDate))
                return ld < rd
            })
        }
        return points.last
    }

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 12) {
                selectionHeader
                if points.isEmpty {
                    ContentUnavailableView("—", systemImage: "chart.xyaxis.line")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if usesDates {
                    datedChart(height: max(320, geo.size.height - 120))
                } else {
                    categoricalChart(height: max(320, geo.size.height - 120))
                }
            }
            .padding()
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.close") { dismiss() }
            }
        }
        .onAppear {
            if let domain = fullXDomain {
                let spanDays = domain.upperBound.timeIntervalSince(domain.lowerBound) / 86_400
                visibleDays = min(45, max(14, spanDays / 3))
                let leading = domain.upperBound.addingTimeInterval(-visibleDuration)
                scrollPosition = max(leading, domain.lowerBound)
            }
            if selectedDate == nil {
                selectedDate = datedPoints.last?.date
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
            }
            Text("boards.chart.zoom_hint")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func datedChart(height: CGFloat) -> some View {
        let yDomain = visibleYDomain(for: datedVisibleValues())
        return Chart {
            ForEach(datedPoints, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Y", point.value)
                )
                .interpolationMethod(.catmullRom)
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Y", point.value)
                )
                .foregroundStyle(Color.accentColor.opacity(0.12))
                .interpolationMethod(.catmullRom)
            }
            if let selectedDate,
               let match = datedPoints.min(by: {
                   abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
               }) {
                RuleMark(x: .value("Date", match.date))
                    .foregroundStyle(Color.secondary.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                PointMark(
                    x: .value("Date", match.date),
                    y: .value("Y", match.value)
                )
                .symbolSize(72)
                .foregroundStyle(Color.accentColor)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel(collisionResolution: .greedy) {
                    if let date = value.as(Date.self) {
                        Text(StructuredUIChartDisplay.compactAxisLabel(from: date))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4))
        }
        .chartXSelection(value: $selectedDate)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: visibleDuration)
        .chartScrollPosition(x: $scrollPosition)
        .simultaneousGesture(zoomGesture)
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if magnifyBaseDays == nil {
                    magnifyBaseDays = visibleDays
                }
                let base = magnifyBaseDays ?? visibleDays
                let totalDays = max(fullSpanDays(), 7)
                visibleDays = min(max(base / value.magnification, 7), totalDays)
            }
            .onEnded { _ in
                magnifyBaseDays = nil
            }
    }

    private func categoricalChart(height: CGFloat) -> some View {
        let labels = points.map(\.rawLabel)
        let ticks = StructuredUIChartDisplay.sparseAxisValues(from: labels, count: 3)
        let yDomain = visibleYDomain(for: points.map(\.value))
        return Chart(points) { point in
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
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: ticks) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let raw = value.as(String.self) {
                        Text(StructuredUIChartDisplay.axisLabel(from: raw))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private func datedVisibleValues() -> [Double] {
        guard let domain = fullXDomain else {
            return datedPoints.map(\.value)
        }
        let start = scrollPosition
        let end = start.addingTimeInterval(visibleDuration)
        let lo = max(start, domain.lowerBound)
        let hi = min(end, domain.upperBound)
        let visible = datedPoints.filter { $0.date >= lo && $0.date <= hi }.map(\.value)
        return visible.isEmpty ? datedPoints.map(\.value) : visible
    }

    private func visibleYDomain(for values: [Double]) -> ClosedRange<Double> {
        guard let minV = values.min(), let maxV = values.max() else { return 0...1 }
        if abs(maxV - minV) < 1e-9 {
            let pad = max(abs(minV) * 0.05, 1)
            return (minV - pad)...(maxV + pad)
        }
        let pad = (maxV - minV) * 0.12
        if minV >= 0, minV <= (maxV - minV) * 0.35 {
            return 0...(maxV + pad)
        }
        return (minV - pad)...(maxV + pad)
    }

    private func fullSpanDays() -> Double {
        guard let domain = fullXDomain else { return visibleDays }
        return max(domain.upperBound.timeIntervalSince(domain.lowerBound) / 86_400, 7)
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
            return axisLabel(from: date)
        }
        return raw
    }

    static func axisLabel(from date: Date) -> String {
        axisDay.string(from: date)
    }

    /// Short axis caption: `2 ноя 22` / `27 сен 26` — fits three columns without collision.
    static func compactAxisLabel(from raw: String) -> String {
        guard let date = parseDate(raw) else { return raw }
        return compactAxisLabel(from: date)
    }

    static func compactAxisLabel(from date: Date) -> String {
        compactAxisDay.string(from: date)
    }

    private static let compactAxisDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("dMMMyy")
        return f
    }()

    static func detailLabel(from raw: String) -> String {
        if let date = parseDate(raw) {
            return detailDay.string(from: date)
        }
        return raw
    }

    static func formatValue(_ value: Double) -> String {
        valueFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// First / middle / last (or fewer) labels so compact chart axes stay readable.
    static func sparseAxisValues(from labels: [String], count: Int = 3) -> [String] {
        guard !labels.isEmpty else { return [] }
        let n = min(max(count, 1), labels.count)
        if n == 1 { return [labels[labels.count / 2]] }
        if n == 2 { return [labels.first!, labels.last!] }
        var out: [String] = []
        var seen = Set<String>()
        for i in 0..<n {
            let idx = Int(round(Double(i) * Double(labels.count - 1) / Double(n - 1)))
            let label = labels[idx]
            if seen.insert(label).inserted {
                out.append(label)
            }
        }
        return out
    }
}
