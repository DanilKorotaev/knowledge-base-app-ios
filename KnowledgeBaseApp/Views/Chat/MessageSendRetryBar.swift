import SwiftUI

struct MessageSendRetryBar: View {
    let errorText: String?
    let isBusy: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if let errorText, !errorText.isEmpty {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            Button(action: onRetry) {
                Label(L10n.string("chat.retry"), systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .disabled(isBusy)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 4)
    }
}
