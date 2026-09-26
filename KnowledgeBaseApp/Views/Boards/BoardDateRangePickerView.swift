import SwiftUI

/// Inclusive date-range calendar: first tap = start, second = end.
/// Month page offset is owned by the parent so TabView survives selection updates.
struct BoardDateRangePickerView: View {
    @Binding var rangeStart: Date?
    @Binding var rangeEnd: Date?
    @Binding var monthOffset: Int

    private let calendar: Calendar
    private let locale: Locale
    private let today: Date
    private let baseMonth: Date
    private let pageOffsets: [Int]

    /// Draft selection kept locally so the first tap after open does not rely on
    /// parent re-render timing (which was resetting TabView to the base month).
    @State private var draftStart: Date?
    @State private var draftEnd: Date?
    @State private var pendingStart: Date?
    @State private var didSeedDraft = false

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
        monthOffset: Binding<Int>,
        initialMonth: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = AppLanguageStore.shared.resolvedLocale,
        today: Date = Date()
    ) {
        _rangeStart = rangeStart
        _rangeEnd = rangeEnd
        _monthOffset = monthOffset
        self.calendar = calendar
        self.locale = locale
        self.today = calendar.startOfDay(for: today)
        self.baseMonth = Self.monthStart(for: initialMonth, calendar: calendar)
        self.pageOffsets = Array(-36 ... 36)
    }

    var body: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayHeader
            BoardMonthTabPager(
                monthOffset: $monthOffset,
                pageOffsets: pageOffsets,
                height: dayGridHeight
            ) { offset in
                dayGrid(for: month(for: offset))
            }
            footer
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .onAppear {
            guard !didSeedDraft else { return }
            draftStart = rangeStart
            draftEnd = rangeEnd
            pendingStart = nil
            didSeedDraft = true
        }
    }

    private var dayGridHeight: CGFloat {
        6 * rowHeight + 5 * rowSpacing
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            Button {
                guard pageOffsets.contains(monthOffset - 1) else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    monthOffset -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!pageOffsets.contains(monthOffset - 1))
            .accessibilityLabel(Text(L10n.string("boards.period.previous_month")))

            Text(monthTitle(for: month(for: monthOffset)))
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(minWidth: 140)

            Button {
                guard pageOffsets.contains(monthOffset + 1) else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    monthOffset += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!pageOffsets.contains(monthOffset + 1))
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

    private func dayGrid(for visibleMonth: Date) -> some View {
        let days = daysInMonth(visibleMonth)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text(selectionSummary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(draftStart != nil ? Color.primary : Color.secondary)
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
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(dayAccessibilityLabel(day)))
    }

    // MARK: - Selection

    private enum DayRole: Equatable {
        case none, start, end, single, middle

        var isEndpoint: Bool {
            switch self {
            case .start, .end, .single: return true
            case .none, .middle: return false
            }
        }
    }

    private var displayStart: Date? {
        if let pendingStart { return pendingStart }
        return draftStart.map { calendar.startOfDay(for: $0) }
    }

    private var displayEnd: Date? {
        if pendingStart != nil { return pendingStart }
        return draftEnd.map { calendar.startOfDay(for: $0) }
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
        let keptOffset = monthOffset

        if let start = pendingStart {
            draftStart = min(start, tapped)
            draftEnd = max(start, tapped)
            pendingStart = nil
        } else {
            pendingStart = tapped
            draftStart = tapped
            draftEnd = tapped
        }

        // Push to parent for Done enablement — then pin month page (TabView can snap on first update).
        rangeStart = draftStart
        rangeEnd = draftEnd
        pinMonthOffset(keptOffset)
    }

    private func pinMonthOffset(_ offset: Int) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            monthOffset = offset
        }
        DispatchQueue.main.async {
            withTransaction(transaction) {
                monthOffset = offset
            }
        }
    }

    // MARK: - Helpers

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
        return L10n.string("boards.period.range_hint_start")
    }

    private func dayAccessibilityLabel(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        return formatter.string(from: day)
    }
}

// MARK: - Isolated pager (keeps TabView selection binding stable)

private struct BoardMonthTabPager<Page: View>: View {
    @Binding var monthOffset: Int
    let pageOffsets: [Int]
    let height: CGFloat
    @ViewBuilder let page: (Int) -> Page

    var body: some View {
        TabView(selection: $monthOffset) {
            ForEach(pageOffsets, id: \.self) { offset in
                page(offset)
                    .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: height)
    }
}
