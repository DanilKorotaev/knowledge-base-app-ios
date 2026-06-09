import SwiftUI

/// Lightweight growing assistant bubble while SSE is active (plain text, no block markdown).
/// Reveals target text with a typewriter effect so bursts of SSE deltas still look incremental.
struct StreamingAssistantBubbleView: View {
    let text: String
    var showsTypingIndicator: Bool
    var isFinishing: Bool = false
    var onRevealedGrowth: (() -> Void)?
    var onRevealComplete: (() -> Void)?

    @State private var revealState = StreamTextRevealState()

    private var isCatchingUp: Bool {
        revealState.revealedText.count < text.count
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(revealState.revealedText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: Self.maxBubbleWidth, alignment: .leading)
                    .padding(12)
                    .background(Color.secondary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                if showsTypingIndicator || isCatchingUp {
                    TypingIndicatorView()
                        .padding(.leading, 8)
                }
            }
            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { syncRevealState() }
        .onChange(of: text) { _, _ in syncRevealState() }
        .onChange(of: isFinishing) { _, _ in syncRevealState() }
        .onDisappear { revealState.reset() }
    }

    private func syncRevealState() {
        revealState.onGrowth = onRevealedGrowth
        revealState.onComplete = onRevealComplete
        revealState.updateTarget(text, finishing: isFinishing)
    }

    private static var maxBubbleWidth: CGFloat {
        let screenWidth = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.width ?? 390
        return min(560, screenWidth * 0.90)
    }
}
