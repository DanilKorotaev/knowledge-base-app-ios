import UIKit

enum NextcloudFileOpenMode: Equatable {
    /// Prefer Nextcloud app deep link when installed; otherwise authenticated web URL.
    case preferred
    /// Always open the Nextcloud app deep link when available.
    case nextcloudApp
    /// Always open the authenticated HTTPS URL (Safari / system browser).
    case safari
}

@MainActor
enum NextcloudFileOpener {
    static func open(_ link: KBFileOpenLink, mode: NextcloudFileOpenMode = .preferred) {
        switch mode {
        case .preferred:
            if let deep = link.nextcloudDeepLink, UIApplication.shared.canOpenURL(deep) {
                UIApplication.shared.open(deep)
            } else {
                UIApplication.shared.open(link.webURL)
            }
        case .nextcloudApp:
            if let deep = link.nextcloudDeepLink, UIApplication.shared.canOpenURL(deep) {
                UIApplication.shared.open(deep)
            } else {
                UIApplication.shared.open(link.webURL)
            }
        case .safari:
            UIApplication.shared.open(link.webURL)
        }
    }
}
