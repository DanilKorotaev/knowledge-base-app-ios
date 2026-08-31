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
        DebugMenuPresenter.shared.present()
    }

    func presentDebugMenuFromSettings() {
        DebugMenuPresenter.shared.present()
    }

    func confirmSendLogs() async {
        showSendLogsConfirm = false
        FileLogger.shared.resetWriter()

        guard let source = LogFilesProvider.shared.currentSessionLogFilePath,
              FileManager.default.fileExists(atPath: source.path)
        else {
            statusMessage = L10n.string("debug.no_log_file")
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
            statusMessage = L10n.string("debug.copy_log_failed")
            return
        }

        guard let handler = chatAttachHandler else {
            statusMessage = L10n.string("debug.open_chat_to_attach")
            try? FileManager.default.removeItem(at: dest)
            return
        }

        let ok = await handler(dest)
        if ok {
            statusMessage = L10n.format("debug.log_attached_format", dest.lastPathComponent)
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
