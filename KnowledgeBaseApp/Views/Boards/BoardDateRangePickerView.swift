import SwiftUI

/// Inclusive date-range calendar: first tap = start, second = end.
/// Optional draft — when both are nil, nothing is selected (current month + today ring).
struct BoardDateRangePickerView: View {
    @Binding var rangeStart: Date?
    @Binding var rangeEnd: Date?

    private let calendar: Calendar
    private let locale: Locale
    private let today: Date

    @State private var visibleMonth: Date
    @State private var pendingStart: Date?

    private let rowHeight: CGFloat = 40
    private let rowSpacing: CGFloat = 4

    /// Approximate content height for a fitted sheet detent (excl. nav bar).
    static let fittedContentHeight: CGFloat = {
        let header: CGFloat = 36
        let weekdays: CGFloat = 28
        let grid: CGFloat = 6 * 40 + 5 * 4
        let footer: CGFloat = 56
        let padding: CGFloat = 12 + 16 + 12
        return header + 12 + weekdays + 12 + grid + 8 + footer + padding
    }()

    init(
        rangeStart: Binding<Date?>,
        rangeEnd: Binding<Date?>,
        initialMonth: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = AppLanguageStore.shared.resolvedLocale,
        today: Date = Date()
    ) {
        _rangeStart = rangeStart
        _rangeEnd = rangeEnd
        self.calendar = calendar
        self.locale = locale
        self.today = calendar.startOfDay(for: today)
        _visibleMonth = State(initialValue: Self.monthStart(for: initialMonth, calendar: calendar))
    }

    var body: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayHeader
            dayGrid(for: visibleMonth)
                .gesture(monthSwipeGesture)
            footer
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(L10n.string("boards.period.previous_month")))

            Text(monthTitle(for: visibleMonth))
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(minWidth: 140)

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(L10n.string("boards.period.next_month")))
            Spacer(minLength: 0)
        }
    }

    private var weekdayHeader: some View {
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

    private func dayGrid(for month: Date) -> some View {
        let days = daysInMonth(month)
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
            spacing: rowSpacing
        ) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: rowHeight)
                }
            }
        }
        .frame(height: 6 * rowHeight + 5 * rowSpacing, alignment: .top)
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40, coordinateSpace: .local)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy), abs(dx) > 50 else { return }
                if dx < 0 {
                    shiftMonth(by: 1)
                } else {
                    shiftMonth(by: -1)
                }
            }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text(selectionSummary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(hasCompleteRange ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity)
            Text(hintText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let role = dayRole(day)
        let isToday = calendar.isDate(day, inSameDayAs: today)

        return Button {
            select(day)
        } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(.body.weight(role.isEndpoint ? .semibold : .regular))
                .foregroundStyle(role.isEndpoint ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: rowHeight)
                .background {
                    ZStack {
                        // Range fill only on middle days — never behind endpoint circles (no “tail”).
                        if role == .middle {
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.22))
                        }
                        if role.isEndpoint {
                            Circle()
                                .fill(Color.accentColor)
                                .padding(4)
                        } else if isToday {
                            Circle()
                                .strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 1.5)
                                .padding(4)
                        }
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(dayAccessibilityLabel(day)))
    }

    // MARK: - Selection

    private enum DayRole: Equatable {
        case none
        case start
        case end
        case single
        case middle

        var isEndpoint: Bool {
            switch self {
            case .start, .end, .single: return true
            case .none, .middle: return false
            }
        }
    }

    private var displayStart: Date? {
        if let pendingStart { return pendingStart }
        return rangeStart.map { calendar.startOfDay(for: $0) }
    }

    private var displayEnd: Date? {
        if pendingStart != nil { return pendingStart }
        return rangeEnd.map { calendar.startOfDay(for: $0) }
    }

    private var hasCompleteRange: Bool {
        pendingStart == nil && rangeStart != nil && rangeEnd != nil
    }

    private func dayRole(_ day: Date) -> DayRole {
        guard let start = displayStart, let end = displayEnd else { return .none }
        let d = calendar.startOfDay(for: day)
        if d < start || d > end { return .none }
        if calendar.isDate(start, inSameDayAs: end) {
            return calendar.isDate(d, inSameDayAs: start) ? .single : .none
        }
        if calendar.isDate(d, inSameDayAs: start) { return .start }
        if calendar.isDate(d, inSameDayAs: end) { return .end }
        return .middle
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
        // New selection — clear any previous range highlight.
        pendingStart = tapped
        rangeStart = tapped
        rangeEnd = tapped
    }

    // MARK: - Helpers

    private func shiftMonth(by delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: visibleMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleMonth = Self.monthStart(for: next, calendar: calendar)
        }
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
        guard let start = displayStart, let end = displayEnd else {
            return L10n.string("boards.period.range_none")
        }
        return BoardPeriodSelection.normalizeRange(from: start, to: end, calendar: calendar)
            .displayLabel(calendar: calendar)
    }

    private var hintText: String {
        if pendingStart != nil {
            return L10n.string("boards.period.range_hint_end")
        }
        if rangeStart == nil {
            return L10n.string("boards.period.range_hint_start")
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
