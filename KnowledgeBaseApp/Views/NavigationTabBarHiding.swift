import SwiftUI
import UIKit

extension View {
    /// Hides the root tab bar during the push transition (UIKit `hidesBottomBarWhenPushed`).
    /// Prefer this over toggling `.toolbar` on the source stack — that causes hitching.
    func hidesTabBarWhenPushed() -> some View {
        background(HidesBottomBarWhenPushedInstaller())
            .toolbar(.hidden, for: .tabBar)
    }
}

/// Sets `hidesBottomBarWhenPushed` on the nearest navigation-stack view controller as early as possible.
private struct HidesBottomBarWhenPushedInstaller: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.applyHiding()
    }

    final class Controller: UIViewController {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            applyHiding()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            applyHiding()
        }

        func applyHiding() {
            guard let stackController = navigationStackMember() else { return }
            if !stackController.hidesBottomBarWhenPushed {
                stackController.hidesBottomBarWhenPushed = true
            }
        }

        private func navigationStackMember() -> UIViewController? {
            var current: UIViewController? = self
            while let controller = current {
                if controller.navigationController?.viewControllers.contains(controller) == true {
                    return controller
                }
                current = controller.parent
            }
            return parent
        }
    }
}
