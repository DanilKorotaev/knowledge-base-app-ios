import SwiftUI
import UIKit

/// Presents the Debug menu as a retained modal sheet so navigation state survives dismiss/reopen
/// for the lifetime of the app process (Settings button and 3-finger gesture share the same host).
@MainActor
final class DebugMenuPresenter {
    static let shared = DebugMenuPresenter()

    private var hostingController: UIHostingController<DebugMenuSheetRoot>?
    private var isPresenting = false

    private init() {}

    var isVisible: Bool {
        hostingController?.presentingViewController != nil
    }

    func present() {
        if let host = hostingController, host.presentingViewController != nil {
            return
        }

        guard let presenter = Self.presentationAnchor() else { return }

        let host: UIHostingController<DebugMenuSheetRoot>
        if let existing = hostingController {
            host = existing
        } else {
            let created = UIHostingController(rootView: DebugMenuSheetRoot())
            created.modalPresentationStyle = .pageSheet
            if let sheet = created.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
            hostingController = created
            host = created
        }

        isPresenting = true
        presenter.present(host, animated: true) { [weak self] in
            self?.isPresenting = false
        }
    }

    func dismiss() {
        hostingController?.dismiss(animated: true)
    }

    private static func presentationAnchor() -> UIViewController? {
        guard var top = KBTopViewController.current else { return nil }
        while let presented = top.presentedViewController {
            // Don't present from the debug sheet itself.
            if presented === DebugMenuPresenter.shared.hostingController {
                break
            }
            top = presented
        }
        if top === DebugMenuPresenter.shared.hostingController {
            return top.presentingViewController
        }
        return top
    }
}

struct DebugMenuSheetRoot: View {
    var body: some View {
        NavigationStack {
            DebugMenuView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.close") {
                            DebugMenuPresenter.shared.dismiss()
                        }
                    }
                }
        }
    }
}
