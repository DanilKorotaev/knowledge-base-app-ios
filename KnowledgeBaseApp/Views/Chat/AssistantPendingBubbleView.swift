import SwiftUI

/// Placeholder bubble before the first SSE token arrives.
struct AssistantPendingBubbleView: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Обработка…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Обработка ответа")
    }
}
