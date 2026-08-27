import Foundation
import Observation

/// Debug shortcuts: shake-to-send logs, modal Debug menu.
@MainActor
@Observable
final class DebugQuickActionsController {
    static let shared = DebugQuickActionsController()

    private static let shakeToSendKey = UserDefaultsKey.debugShakeToSendLogs

    var isShakeToSendLogsEnabled: Bool {
        didSet {
            UserDefaultsService.shared.set(isShakeToSendLogsEnabled, forKey: Self.shakeToSendKey)
        }
    }

    var showSendLogsConfirm = false
    var showDebugMenuSheet = false
    var statusMessage: String?

    /// Returns `true` when the active chat accepted the log attachment.
    private var chatAttachHandler: ((URL) async -> Bool)?

    private init() {
        isShakeToSendLogsEnabled =
            (UserDefaultsService.shared.object(forKey: Self.shakeToSendKey) as? Bool) ?? false
    }

    func registerChatLogAttachHandler(_ handler: ((URL) async -> Bool)?) {
        chatAttachHandler = handler
    }

    func handleDeviceShake() {
        guard isShakeToSendLogsEnabled else { return }
        guard !showSendLogsConfirm else { return }
        showSendLogsConfirm = true
    }

    func presentDebugMenuFromMainGesture() {
        showDebugMenuSheet = true
    }

    func confirmSendLogs() async {
        showSendLogsConfirm = false
        FileLogger.shared.resetWriter()

        guard let source = LogFilesProvider.shared.currentSessionLogFilePath,
              FileManager.default.fileExists(atPath: source.path)
        else {
            statusMessage = "No log file yet. Enable file logging in Debug → Logs → Settings."
            return
        }

        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("kb-debug-\(LogSession.shared.id).log")
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: source, to: dest)
        } catch {
            statusMessage = "Could not copy log file."
            return
        }

        guard let handler = chatAttachHandler else {
            statusMessage = "Open a chat to attach the log file."
            try? FileManager.default.removeItem(at: dest)
            return
        }

        let ok = await handler(dest)
        if ok {
            statusMessage = "Log attached: \(dest.lastPathComponent)"
        } else {
            try? FileManager.default.removeItem(at: dest)
        }
    }

    func cancelSendLogs() {
        showSendLogsConfirm = false
    }

    func clearStatusMessage() {
        statusMessage = nil
    }
}
