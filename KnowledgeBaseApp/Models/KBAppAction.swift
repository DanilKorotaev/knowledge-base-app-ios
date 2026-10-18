import Foundation

/// Unified client action payload (boards taps, future pushes / deep links).
/// Wire shape mirrors Youla screen/target style: `{ "type": "…", …params }`.
struct KBAppAction: Codable, Equatable, Sendable, Hashable {
    /// Action kind, e.g. `open_session`, `open_board`, `open_tab`, `open_chart_detail`,
    /// `compose_camera`, `remote_ui`, `open_debug_menu`, `alert`, `share_logs`.
    let type: String
    let sessionId: String?
    let boardId: String?
    let chartId: String?
    let tab: String?
    let title: String?
    let message: String?
    let url: String?
    /// HTTP method for `remote_ui` (default GET). Reserved for future POST bodies.
    let method: String?
    /// When true, Share Extension may offer this action as a share destination.
    let share: Bool?
    /// Label in the Share Extension destinations list.
    let shareLabel: String?

    enum CodingKeys: String, CodingKey {
        case type
        case sessionId = "session_id"
        case boardId = "board_id"
        case chartId = "chart_id"
        case tab
        case title
        case message
        case url
        case method
        case share
        case shareLabel = "share_label"
    }

    init(
        type: String,
        sessionId: String? = nil,
        boardId: String? = nil,
        chartId: String? = nil,
        tab: String? = nil,
        title: String? = nil,
        message: String? = nil,
        url: String? = nil,
        method: String? = nil,
        share: Bool? = nil,
        shareLabel: String? = nil
    ) {
        self.type = type
        self.sessionId = sessionId
        self.boardId = boardId
        self.chartId = chartId
        self.tab = tab
        self.title = title
        self.message = message
        self.url = url
        self.method = method
        self.share = share
        self.shareLabel = shareLabel
    }

    func withURL(_ url: String) -> KBAppAction {
        KBAppAction(
            type: type,
            sessionId: sessionId,
            boardId: boardId,
            chartId: chartId,
            tab: tab,
            title: title,
            message: message,
            url: url,
            method: method,
            share: share,
            shareLabel: shareLabel
        )
    }

    var isShareDestination: Bool {
        share == true && type == "remote_ui"
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

    /// Open chat (optional `session_id`, else new draft), seed composer `message`, present camera.
    static func composeCamera(sessionId: String? = nil, message: String? = nil) -> KBAppAction {
        KBAppAction(type: "compose_camera", sessionId: sessionId, message: message)
    }

    static func remoteUI(url: String, title: String? = nil, share: Bool = false, shareLabel: String? = nil) -> KBAppAction {
        KBAppAction(
            type: "remote_ui",
            title: title,
            url: url,
            share: share ? true : nil,
            shareLabel: shareLabel
        )
    }

    static let openDebugMenu = KBAppAction(type: "open_debug_menu")
    static let shareLogs = KBAppAction(type: "share_logs")
}

extension KBAppAction {
    /// Known navigation / system tabs.
    enum Tab: String, CaseIterable {
        case sessions
        case boards
        case actions
        case health
        case settings
    }

    var resolvedTab: Tab? {
        guard let tab, let value = Tab(rawValue: tab.lowercased()) else { return nil }
        return value
    }
}
