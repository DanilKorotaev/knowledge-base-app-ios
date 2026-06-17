import SwiftUI

struct VoiceDefaultExpiredBanner: View {
    let notice: VoiceDefaultExpiredNotice
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: notice.iconName)
                .font(.title3)
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(notice.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(notice.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.22), lineWidth: 1)
                }
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Cleared") {
    List {
        VoiceDefaultExpiredBanner(notice: .cleared, onDismiss: {})
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
    .listStyle(.plain)
}

#Preview("Restored") {
    List {
        VoiceDefaultExpiredBanner(notice: .restored(sessionTitle: "Inbox"), onDismiss: {})
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
    .listStyle(.plain)
}
