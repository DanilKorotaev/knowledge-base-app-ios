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

enum BoardPeriodSelection: Equatable {
    case all
    case month(year: Int, month: Int)

    var queryValue: String? {
        switch self {
        case .all:
            return nil
        case let .month(year, month):
            return String(format: "%04d-%02d", year, month)
        }
    }

    static func currentMonth(from date: Date = Date(), calendar: Calendar = .current) -> BoardPeriodSelection {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return .month(year: comps.year ?? 2026, month: comps.month ?? 1)
    }

    func shifting(byMonths delta: Int, calendar: Calendar = .current) -> BoardPeriodSelection {
        switch self {
        case .all:
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

    func displayLabel(calendar: Calendar = .current, locale: Locale = .current) -> String {
        switch self {
        case .all:
            return L10n.string("boards.period.all")
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

    func load() async {
        isLoading = detail == nil
        loadError = nil
        defer { isLoading = false }

        do {
            detail = try await client.fetchBoard(id: boardId, period: period.queryValue)
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
            detail = try await client.refreshBoard(id: boardId, period: period.queryValue)
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
