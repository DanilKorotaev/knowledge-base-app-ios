import SwiftUI

extension View {
    /// Hides the root tab bar while this screen is visible in a pushed navigation stack.
    func hidesTabBarWhenPushed() -> some View {
        toolbar(.hidden, for: .tabBar)
    }
}
