import SwiftUI

/// Lightweight growing assistant bubble while SSE is active (plain text, no block markdown).
struct StreamingAssistantBubbleView: View {
    let text: String
    var showsTypingIndicator: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: Self.maxBubbleWidth, alignment: .leading)
                    .padding(12)
                    .background(Color.secondary.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                if showsTypingIndicator {
                    TypingIndicatorView()
                        .padding(.leading, 8)
                }
            }
            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.12), value: text.count)
    }

    private static var maxBubbleWidth: CGFloat {
        let screenWidth = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds.width ?? 390
        return min(560, screenWidth * 0.90)
    }
}
