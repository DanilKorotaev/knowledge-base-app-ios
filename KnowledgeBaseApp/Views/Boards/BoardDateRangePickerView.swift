import SwiftUI

/// Inclusive date-range calendar: first tap = start, second = end (range fills in between).
struct BoardDateRangePickerView: View {
    @Binding var rangeStart: Date
    @Binding var rangeEnd: Date

    private let calendar: Calendar
    private let locale: Locale
    private let today: Date
    private let baseMonth: Date

    /// Month page relative to `baseMonth` (0 = initial month when opened).
    @State private var monthOffset: Int = 0
    /// When non-nil, waiting for the end tap after choosing a new start.
    @State private var pendingStart: Date?

    private let monthWindow = -36 ... 36

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
        self.baseMonth = Self.monthStart(for: initial, calendar: calendar)
    }

    var body: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayHeader
            TabView(selection: $monthOffset) {
                ForEach(Array(monthWindow), id: \.self) { offset in
                    dayGrid(for: month(for: offset))
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: dayGridHeight)
            footer
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Header (chevrons next to title — not under Cancel/Done)

    private var monthHeader: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    monthOffset -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!monthWindow.contains(monthOffset - 1))
            .accessibilityLabel(Text(L10n.string("boards.period.previous_month")))

            Text(monthTitle(for: month(for: monthOffset)))
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(minWidth: 140)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    monthOffset += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!monthWindow.contains(monthOffset + 1))
            .accessibilityLabel(Text(L10n.string("boards.period.next_month")))
            Spacer(minLength: 0)
        }
    }

    private var weekdayHeader: some View {
        // Index-based ForEach: short symbols collide ("T"/"T", "S"/"S") and must not share `id: \.self`.
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
            }
        }
    }

    private func dayGrid(for visibleMonth: Date) -> some View {
        let days = daysInMonth(visibleMonth)
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

    private var dayGridHeight: CGFloat {
        // 6 rows × 40 + spacing — keeps TabView height stable across months.
        6 * 40 + 5 * 4
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
        .padding(.bottom, 8)
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
        if let pendingStart {
            return pendingStart
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
        pendingStart = tapped
        rangeStart = tapped
        rangeEnd = tapped
    }

    private func isInSelectedRange(_ day: Date) -> Bool {
        let d = calendar.startOfDay(for: day)
        return d >= effectiveStart && d <= effectiveEnd
    }

    // MARK: - Calendar helpers

    private func month(for offset: Int) -> Date {
        calendar.date(byAdding: .month, value: offset, to: baseMonth) ?? baseMonth
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date)
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        // Prefer short (Пн/Вт…) — veryShort collapses to identical letters and looked "missing".
        let symbols = formatter.shortWeekdaySymbols ?? formatter.veryShortWeekdaySymbols ?? []
        let first = calendar.firstWeekday - 1
        guard symbols.count == 7, (0 ..< 7).contains(first) else { return symbols }
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private func daysInMonth(_ visibleMonth: Date) -> [Date?] {
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
