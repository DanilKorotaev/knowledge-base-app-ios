import Foundation

/// Catalog entry from `GET /api/boards` — client has no knowledge of vault paths or domain.
struct KBBoard: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    /// SF Symbol name suggested by the server (optional).
    let icon: String?
    /// `cached_view` | `remote` | `system`
    let kind: String
    let sortOrder: Int
    let enabled: Bool
    let listCell: KBBoardListCell?
    let renderedAt: String?
    /// `none` | `month` | `range` — how the client should present the period control.
    let periodUi: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case icon
        case kind
        case sortOrder = "sort_order"
        case enabled
        case listCell = "list_cell"
        case renderedAt = "rendered_at"
        case periodUi = "period_ui"
    }

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        kind: String = "cached_view",
        sortOrder: Int = 0,
        enabled: Bool = true,
        listCell: KBBoardListCell? = nil,
        renderedAt: String? = nil,
        periodUi: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.kind = kind
        self.sortOrder = sortOrder
        self.enabled = enabled
        self.listCell = listCell
        self.renderedAt = renderedAt
        self.periodUi = periodUi
    }

    var systemImageName: String {
        if let icon, !icon.isEmpty { return icon }
        switch kind {
        case "remote":
            return "network"
        case "system":
            return "gearshape.2"
        default:
            return "square.grid.2x2"
        }
    }

    var resolvedPeriodUi: BoardPeriodUIMode {
        BoardPeriodUIMode(rawValue: (periodUi ?? "month").lowercased()) ?? .month
    }
}

enum BoardPeriodUIMode: String, Sendable {
    case none
    case month
    case range
}

struct KBBoardListMetric: Codable, Equatable, Hashable, Sendable {
    let label: String
    let value: String
}

/// Optional rich preview for the boards list (server-driven; no domain hardcoding).
struct KBBoardListCell: Codable, Equatable, Hashable, Sendable {
    /// `plain` | `metrics` | `status`
    let kind: String?
    let title: String?
    let subtitle: String?
    let metrics: [KBBoardListMetric]?
    let statusText: String?
    /// `ok` | `warn` | `error` | `info`
    let statusTone: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case title
        case subtitle
        case metrics
        case statusText = "status_text"
        case statusTone = "status_tone"
    }

    init(
        kind: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        metrics: [KBBoardListMetric]? = nil,
        statusText: String? = nil,
        statusTone: String? = nil
    ) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.metrics = metrics
        self.statusText = statusText
        self.statusTone = statusTone
    }
}

/// Full board payload from `GET /api/boards/{id}`.
struct KBBoardDetail: Codable, Equatable, Sendable {
    let board: KBBoard
    let document: KBStructuredUIDocument
    let renderedAt: String?

    enum CodingKeys: String, CodingKey {
        case board
        case document
        case renderedAt = "rendered_at"
    }
}

struct KBBoardsListResponse: Codable, Equatable, Sendable {
    let boards: [KBBoard]
    let total: Int?

    enum CodingKeys: String, CodingKey {
        case boards
        case items
        case total
    }

    init(boards: [KBBoard], total: Int? = nil) {
        self.boards = boards
        self.total = total ?? boards.count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let boards = try container.decodeIfPresent([KBBoard].self, forKey: .boards) {
            self.boards = boards
        } else if let items = try container.decodeIfPresent([KBBoard].self, forKey: .items) {
            self.boards = items
        } else {
            self.boards = []
        }
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? boards.count
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(boards, forKey: .boards)
        try container.encodeIfPresent(total, forKey: .total)
    }
}
