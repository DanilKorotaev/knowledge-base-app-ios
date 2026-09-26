import SwiftUI

/// Inclusive date-range calendar: first tap = start, second = end (range fills in between).
struct BoardDateRangePickerView: View {
    @Binding var rangeStart: Date
    @Binding var rangeEnd: Date

    private let calendar: Calendar
    private let locale: Locale
    private let today: Date

    @State private var visibleMonth: Date
    /// When non-nil, waiting for the end tap after choosing a new start.
    @State private var pendingStart: Date?

    init(
        rangeStart: Binding<Date>,
        rangeEnd: Binding<Date>,
        calendar: Calendar = .current,
        locale: Locale = AppLanguageStore.shared.resolvedLocale,
        today: Date = Date()
    ) {
        _rangeStart = rangeStart
        _rangeEnd = rangeEnd
        self.calendar = calendar
        self.locale = locale
        self.today = calendar.startOfDay(for: today)
        let initial = calendar.startOfDay(for: rangeStart.wrappedValue)
        _visibleMonth = State(initialValue: Self.monthStart(for: initial, calendar: calendar))
    }

    var body: some View {
        VStack(spacing: 16) {
            monthHeader
            weekdayHeader
            dayGrid
            footer
        }
        .padding(.horizontal)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text(L10n.string("boards.period.previous_month")))

            Text(monthTitle)
                .font(.headline)
                .frame(maxWidth: .infinity)

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text(L10n.string("boards.period.next_month")))
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
            }
        }
    }

    private var dayGrid: some View {
        let days = daysInVisibleMonth()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text(selectionSummary)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
            Text(hintText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    private func dayCell(_ day: Date) -> some View {
        let inRange = isInSelectedRange(day)
        let isStart = calendar.isDate(day, inSameDayAs: effectiveStart)
        let isEnd = calendar.isDate(day, inSameDayAs: effectiveEnd)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let isEndpoint = isStart || isEnd
        let multiDay = !calendar.isDate(effectiveStart, inSameDayAs: effectiveEnd)

        return Button {
            select(day)
        } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(.body.weight(isEndpoint ? .semibold : .regular))
                .foregroundStyle(isEndpoint ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background {
                    ZStack {
                        if inRange, multiDay {
                            UnevenRoundedRectangle(
                                topLeadingRadius: isStart ? 20 : 0,
                                bottomLeadingRadius: isStart ? 20 : 0,
                                bottomTrailingRadius: isEnd ? 20 : 0,
                                topTrailingRadius: isEnd ? 20 : 0
                            )
                            .fill(Color.accentColor.opacity(isEndpoint ? 0.35 : 0.18))
                        }
                        if isEndpoint {
                            Circle()
                                .fill(Color.accentColor)
                                .padding(4)
                        } else if isToday {
                            Circle()
                                .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1)
                                .padding(4)
                        }
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(dayAccessibilityLabel(day)))
    }

    // MARK: - Selection

    private var effectiveStart: Date {
        pendingStart ?? calendar.startOfDay(for: rangeStart)
    }

    private var effectiveEnd: Date {
        if pendingStart != nil {
            return pendingStart!
        }
        return calendar.startOfDay(for: rangeEnd)
    }

    private func select(_ day: Date) {
        let tapped = calendar.startOfDay(for: day)
        if let start = pendingStart {
            let a = min(start, tapped)
            let b = max(start, tapped)
            rangeStart = a
            rangeEnd = b
            pendingStart = nil
            return
        }
        // Start a new range; keep single-day selection until the second tap.
        pendingStart = tapped
        rangeStart = tapped
        rangeEnd = tapped
    }

    private func isInSelectedRange(_ day: Date) -> Bool {
        let d = calendar.startOfDay(for: day)
        return d >= effectiveStart && d <= effectiveEnd
    }

    // MARK: - Calendar helpers

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: visibleMonth)
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbols = formatter.veryShortWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? []
        let first = calendar.firstWeekday - 1
        guard symbols.count == 7, first >= 0 else { return symbols }
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private func daysInVisibleMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday
        else {
            return []
        }
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: leading)
        var cursor = monthInterval.start
        while cursor < monthInterval.end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    private func shiftMonth(by delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: visibleMonth) else { return }
        visibleMonth = Self.monthStart(for: next, calendar: calendar)
    }

    private static func monthStart(for date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    private var selectionSummary: String {
        BoardPeriodSelection.normalizeRange(from: effectiveStart, to: effectiveEnd, calendar: calendar)
            .displayLabel(calendar: calendar)
    }

    private var hintText: String {
        if pendingStart != nil {
            return L10n.string("boards.period.range_hint_end")
        }
        return L10n.string("boards.period.range_hint_start")
    }

    private func dayAccessibilityLabel(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        return formatter.string(from: day)
    }
}
