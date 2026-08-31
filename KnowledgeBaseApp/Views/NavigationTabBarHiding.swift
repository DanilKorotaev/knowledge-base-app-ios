import SwiftUI

extension View {
    /// Hides the root tab bar while this screen is visible in a pushed navigation stack.
    /// Prefer driving hide from the stack root via `navigationPath` when possible — that
    /// animates with the push. Use this on destinations as a safety net (SwiftUI only).
    func hidesTabBarWhenPushed() -> some View {
        toolbar(.hidden, for: .tabBar)
    }
}
