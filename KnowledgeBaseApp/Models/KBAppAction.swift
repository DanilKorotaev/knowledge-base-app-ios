import Foundation

/// Unified client action payload (boards taps, future pushes / deep links).
/// Wire shape mirrors Youla screen/target style: `{ "type": "…", …params }`.
struct KBAppAction: Codable, Equatable, Sendable, Hashable {
    /// Action kind, e.g. `open_session`, `open_board`, `open_tab`, `open_chart_detail`,
    /// `open_debug_menu`, `alert`, `share_logs`.
    let type: String
    let sessionId: String?
    let boardId: String?
    let chartId: String?
    let tab: String?
    let title: String?
    let message: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case type
        case sessionId = "session_id"
        case boardId = "board_id"
        case chartId = "chart_id"
        case tab
        case title
        case message
        case url
    }

    init(
        type: String,
        sessionId: String? = nil,
        boardId: String? = nil,
        chartId: String? = nil,
        tab: String? = nil,
        title: String? = nil,
        message: String? = nil,
        url: String? = nil
    ) {
        self.type = type
        self.sessionId = sessionId
        self.boardId = boardId
        self.chartId = chartId
        self.tab = tab
        self.title = title
        self.message = message
        self.url = url
    }

    static func openSession(id: String) -> KBAppAction {
        KBAppAction(type: "open_session", sessionId: id)
    }

    static func openBoard(id: String) -> KBAppAction {
        KBAppAction(type: "open_board", boardId: id)
    }

    static func openTab(_ tab: String) -> KBAppAction {
        KBAppAction(type: "open_tab", tab: tab)
    }

    static func openChartDetail(chartId: String? = nil) -> KBAppAction {
        KBAppAction(type: "open_chart_detail", chartId: chartId)
    }

    static func alert(title: String, message: String) -> KBAppAction {
        KBAppAction(type: "alert", title: title, message: message)
    }

    static let openDebugMenu = KBAppAction(type: "open_debug_menu")
    static let shareLogs = KBAppAction(type: "share_logs")
}

extension KBAppAction {
    /// Known navigation / system tabs.
    enum Tab: String, CaseIterable {
        case sessions
        case boards
        case health
        case settings
    }

    var resolvedTab: Tab? {
        guard let tab, let value = Tab(rawValue: tab.lowercased()) else { return nil }
        return value
    }
}
