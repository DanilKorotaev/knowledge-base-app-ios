import SwiftUI

struct NotificationsListView: View {
    var onOpenSession: ((Int) -> Void)?

    @State private var items: [KBNotification] = []
    @State private var unreadCount = 0
    @State private var isLoading = false
    @State private var errorText: String?

    private var client: NotificationsAPIClientProtocol {
        URLSessionNotificationsAPIClient() ?? StubNotificationsAPIClient()
    }

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorText, items.isEmpty {
                ContentUnavailableView(
                    "notifications.error.title",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorText)
                )
            } else if items.isEmpty {
                ContentUnavailableView(
                    "notifications.empty.title",
                    systemImage: "bell.slash",
                    description: Text("notifications.empty.footer")
                )
            } else {
                List {
                    ForEach(items) { note in
                        Button {
                            Task { await open(note) }
                        } label: {
                            NotificationRowView(note: note)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("notifications.title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("notifications.mark_all_read") {
                    Task { await markAllRead() }
                }
                .disabled(unreadCount == 0 || items.isEmpty)
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
    }

    @MainActor
    private func reload() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            let response = try await client.fetchNotifications(limit: 50)
            items = response.notifications
            unreadCount = response.unreadCount
            NotificationBadgeStore.shared.unreadCount = response.unreadCount
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor
    private func open(_ note: KBNotification) async {
        if note.unread {
            do {
                let remaining = try await client.markRead(id: note.id)
                unreadCount = remaining
                NotificationBadgeStore.shared.unreadCount = remaining
                if let idx = items.firstIndex(where: { $0.id == note.id }) {
                    items[idx].unread = false
                    items[idx].readAt = items[idx].readAt ?? "read"
                }
            } catch {
                errorText = error.localizedDescription
            }
        }
        if let sessionId = note.sessionId {
            onOpenSession?(sessionId)
        }
    }

    @MainActor
    private func markAllRead() async {
        do {
            try await client.markAllRead()
            unreadCount = 0
            NotificationBadgeStore.shared.unreadCount = 0
            items = items.map { note in
                var copy = note
                copy.unread = false
                copy.readAt = copy.readAt ?? "read"
                return copy
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private struct NotificationRowView: View {
    let note: KBNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: note.systemImageName)
                .foregroundStyle(note.unread ? Color.accentColor : Color.secondary)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.title)
                        .font(.body.weight(note.unread ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    if note.unread {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                    }
                }
                if !note.body.isEmpty {
                    Text(note.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                HStack(spacing: 6) {
                    if let source = note.sourceKey, !source.isEmpty {
                        Text(source)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if let createdAt = note.createdAt, !createdAt.isEmpty {
                        Text(createdAt)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("notifications.row.\(note.id)")
    }
}

/// Shared unread badge for the main toolbar bell.
@Observable
final class NotificationBadgeStore {
    static let shared = NotificationBadgeStore()
    var unreadCount: Int = 0

    @MainActor
    func refresh() async {
        guard let client = URLSessionNotificationsAPIClient() else { return }
        do {
            unreadCount = try await client.fetchUnreadCount()
        } catch {
            // Keep last known count on transient errors.
        }
    }
}
