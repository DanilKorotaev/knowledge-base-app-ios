import SwiftUI

/// Placeholder bubble before the first SSE token arrives.
struct AssistantPendingBubbleView: View {
    var activityLabel: String?

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
                if let activityLabel, !activityLabel.isEmpty {
                    Text(activityLabel)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .accessibilityHidden(true)
                }
            }
            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pendingAccessibilityLabel)
        .accessibilityValue(activityAccessibilityValue)
    }

    private var pendingAccessibilityLabel: String {
        "Обработка ответа"
    }

    private var activityAccessibilityValue: String {
        guard let activityLabel, !activityLabel.isEmpty else { return "" }
        return activityLabel
    }
}
