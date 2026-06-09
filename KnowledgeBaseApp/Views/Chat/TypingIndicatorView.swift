import SwiftUI

/// Three bouncing dots shown while the assistant reply is in progress.
struct TypingIndicatorView: View {
    @State private var animationPhase = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.75))
                    .frame(width: 6, height: 6)
                    .offset(y: animationPhase ? -4 : 0)
                    .animation(
                        .easeInOut(duration: 0.45)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animationPhase
                    )
            }
        }
        .padding(.horizontal, 4)
        .onAppear { animationPhase = true }
        .onDisappear { animationPhase = false }
        .accessibilityLabel("Assistant is typing")
    }
}
