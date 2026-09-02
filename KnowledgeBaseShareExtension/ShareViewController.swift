import SwiftUI
import UIKit

@objc(ShareViewController)
final class ShareViewController: UIViewController {
    private let viewModel = ShareComposeViewModel()
    private var hostingController: UIHostingController<ShareComposeView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let root = ShareComposeView(
            viewModel: viewModel,
            onCancel: { [weak self] in self?.cancel() },
            onFinished: { [weak self] in self?.complete() }
        )
        let host = UIHostingController(rootView: root)
        hostingController = host
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)

        Task { @MainActor in
            await viewModel.bootstrap(extensionContext: self.extensionContext)
        }
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func cancel() {
        let error = NSError(
            domain: "KnowledgeBaseShareExtension",
            code: NSUserCancelledError,
            userInfo: nil
        )
        extensionContext?.cancelRequest(withError: error)
    }
}
