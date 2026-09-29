import Foundation
import Observation

/// Cross-tab router for ``KBAppAction`` (boards → chat, tabs, alerts, debug).
@MainActor
@Observable
final class KBAppActionCenter {
    static let shared = KBAppActionCenter()

    struct AlertRequest: Equatable, Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    /// Open chat for this session id (same path as push / deep link).
    var pendingSessionId: String?
    /// Switch to Overview and open this board.
    var pendingBoardId: String?
    /// Switch root tab: `sessions` | `boards` | `health` | `settings`.
    var pendingTab: KBAppAction.Tab?
    var pendingAlert: AlertRequest?
    var pendingOpenDebugMenu = false
    var pendingShareLogs = false

    private init() {}

    func perform(_ action: KBAppAction) {
        switch action.type {
        case "open_session":
            guard let sessionId = action.sessionId?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !sessionId.isEmpty
            else { return }
            pendingTab = .sessions
            pendingSessionId = sessionId
        case "open_board":
            guard let boardId = action.boardId?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !boardId.isEmpty
            else { return }
            pendingTab = .boards
            pendingBoardId = boardId
        case "open_tab":
            pendingTab = action.resolvedTab
        case "open_debug_menu":
            pendingOpenDebugMenu = true
        case "share_logs":
            pendingShareLogs = true
        case "alert":
            let title = action.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let message = action.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !title.isEmpty || !message.isEmpty else { return }
            pendingAlert = AlertRequest(
                title: title.isEmpty ? L10n.string("common.ok") : title,
                message: message
            )
        case "open_chart_detail":
            // Handled locally by the board / structured UI host (needs series from the node).
            break
        default:
            // Forward-compatible: unknown types are ignored until a client build supports them.
            break
        }
    }

    func clearPendingSession() {
        pendingSessionId = nil
    }

    func clearPendingBoard() {
        pendingBoardId = nil
    }

    func clearPendingAlert() {
        pendingAlert = nil
    }
}
