import SwiftUI

/// Compact sync status row for sessions list and chat (SWR).
struct SyncStatusBannerView: View {
    let status: SyncStatus

    var body: some View {
        HStack(spacing: 8) {
            if case .refreshing = status {
                ProgressView()
                    .controlSize(.small)
            } else if case .offline = status {
                Image(systemName: "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if case .failed = status {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if case .upToDate = status {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Text(status.displayText)
                .font(.caption)
                .foregroundStyle(status.isProminent ? .primary : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(status.displayText)
    }

    private var backgroundColor: Color {
        switch status {
        case .failed:
            return Color.orange.opacity(0.12)
        case .offline:
            return Color.secondary.opacity(0.12)
        case .refreshing:
            return Color.accentColor.opacity(0.08)
        case .upToDate:
            return Color.clear
        case .idle:
            return Color.clear
        }
    }
}
