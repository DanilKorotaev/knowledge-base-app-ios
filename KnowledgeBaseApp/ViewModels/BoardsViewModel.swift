import Foundation
import Observation

@MainActor
@Observable
final class BoardsViewModel {
    private let client: BoardsAPIClientProtocol

    var boards: [KBBoard] = []
    var isLoading = false
    var isRefreshing = false
    var loadError: String?
    var didLoadOnce = false

    init(client: BoardsAPIClientProtocol) {
        self.client = client
    }

    func loadIfNeeded() async {
        guard !didLoadOnce else { return }
        didLoadOnce = true
        await load(showFullScreenLoading: true)
    }

    func reload() async {
        await load(showFullScreenLoading: boards.isEmpty)
    }

    func load(showFullScreenLoading: Bool) async {
        if showFullScreenLoading {
            isLoading = true
        } else {
            isRefreshing = true
        }
        loadError = nil
        defer {
            isLoading = false
            isRefreshing = false
        }

        do {
            boards = try await client.fetchBoards()
        } catch {
            if boards.isEmpty {
                loadError = error.localizedDescription
            }
        }
    }
}

enum BoardPeriodSelection: Equatable, Hashable {
    case all
    case month(year: Int, month: Int)
    case range(from: Date, to: Date)

    var query: BoardPeriodQuery {
        switch self {
        case .all:
            return .all
        case let .month(year, month):
            return BoardPeriodQuery(
                period: String(format: "%04d-%02d", year, month),
                dateFrom: nil,
                dateTo: nil
            )
        case let .range(from, to):
            return BoardPeriodQuery(
                period: nil,
                dateFrom: Self.isoDay(from),
                dateTo: Self.isoDay(to)
            )
        }
    }

    /// Legacy accessor used by older call sites.
    var queryValue: String? { query.period }

    private static func isoDay(_ date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            comps.year ?? 1970,
            comps.month ?? 1,
            comps.day ?? 1
        )
    }

    static func currentMonth(from date: Date = Date(), calendar: Calendar = .current) -> BoardPeriodSelection {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return .month(year: comps.year ?? 2026, month: comps.month ?? 1)
    }

    static func normalizeRange(from: Date, to: Date, calendar: Calendar = .current) -> BoardPeriodSelection {
        let start = calendar.startOfDay(for: min(from, to))
        let end = calendar.startOfDay(for: max(from, to))
        return .range(from: start, to: end)
    }

    static func == (lhs: BoardPeriodSelection, rhs: BoardPeriodSelection) -> Bool {
        switch (lhs, rhs) {
        case (.all, .all):
            return true
        case let (.month(ly, lm), .month(ry, rm)):
            return ly == ry && lm == rm
        case let (.range(lf, lt), .range(rf, rt)):
            return Self.isoDay(lf) == Self.isoDay(rf) && Self.isoDay(lt) == Self.isoDay(rt)
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .all:
            hasher.combine(0)
        case let .month(year, month):
            hasher.combine(1)
            hasher.combine(year)
            hasher.combine(month)
        case let .range(from, to):
            hasher.combine(2)
            hasher.combine(Self.isoDay(from))
            hasher.combine(Self.isoDay(to))
        }
    }

    func shifting(byMonths delta: Int, calendar: Calendar = .current) -> BoardPeriodSelection {
        switch self {
        case .all, .range:
            return Self.currentMonth(calendar: calendar).shifting(byMonths: delta, calendar: calendar)
        case let .month(year, month):
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 1
            guard let base = calendar.date(from: comps),
                  let shifted = calendar.date(byAdding: .month, value: delta, to: base)
            else {
                return self
            }
            return Self.currentMonth(from: shifted, calendar: calendar)
        }
    }

    func displayLabel(calendar: Calendar = .current) -> String {
        let locale = AppLanguageStore.shared.resolvedLocale
        switch self {
        case .all:
            return L10n.string("boards.period.all", locale: locale)
        case let .month(year, month):
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 1
            guard let date = calendar.date(from: comps) else {
                return queryValue ?? ""
            }
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
            return formatter.string(from: date)
        case let .range(from, to):
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
            let start = formatter.string(from: from)
            let end = formatter.string(from: to)
            if start == end {
                return start
            }
            return "\(start) – \(end)"
        }
    }
}

@MainActor
@Observable
final class BoardDetailViewModel {
    private let client: BoardsAPIClientProtocol
    let boardId: String

    var detail: KBBoardDetail?
    var isLoading = false
    var isRefreshing = false
    var loadError: String?
    var period: BoardPeriodSelection = .all

    init(boardId: String, client: BoardsAPIClientProtocol) {
        self.boardId = boardId
        self.client = client
    }

    var periodUi: BoardPeriodUIMode {
        detail?.board.resolvedPeriodUi ?? .month
    }

    /// Current month and the five previous months for the period menu.
    func recentMonthOptions(calendar: Calendar = .current) -> [BoardPeriodSelection] {
        let current = BoardPeriodSelection.currentMonth(calendar: calendar)
        return (0 ..< 6).compactMap { offset in
            current.shifting(byMonths: -offset, calendar: calendar)
        }
    }

    func load() async {
        isLoading = detail == nil
        loadError = nil
        defer { isLoading = false }

        do {
            detail = try await client.fetchBoard(id: boardId, query: period.query)
        } catch {
            if detail == nil {
                loadError = error.localizedDescription
            }
        }
    }

    func refresh() async {
        isRefreshing = true
        loadError = nil
        defer { isRefreshing = false }

        do {
            detail = try await client.refreshBoard(id: boardId, query: period.query)
        } catch {
            if detail == nil {
                loadError = error.localizedDescription
            }
        }
    }

    func setPeriod(_ newPeriod: BoardPeriodSelection) async {
        guard newPeriod != period else { return }
        period = newPeriod
        await load()
    }
}
