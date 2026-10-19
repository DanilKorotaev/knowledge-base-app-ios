import SwiftUI
import UIKit

/// Tappable list cell: optional leading SF Symbol / remote image, title, subtitle, chevron.
/// Optional `swipe_actions` → trailing swipe (via embedded List) + long-press context menu.
struct StructuredUIListRowNodeView: View {
    let node: KBStructuredUINode
    var isSending: Bool
    var onAction: (String, String, [String: StructuredUIFormValue]?) -> Void
    var onAppAction: ((KBAppAction, KBStructuredUINode) -> Void)?

    @State private var remoteImage: UIImage?

    private var title: String { node.label ?? node.text ?? "" }
    private var subtitle: String? {
        guard let text = node.text, !text.isEmpty, node.label != nil else { return nil }
        return text
    }

    private var rowActions: [KBStructuredUISwipeAction] {
        node.swipeActions ?? []
    }

    var body: some View {
        Group {
            if rowActions.isEmpty {
                plainRow
            } else {
                swipeableRow
            }
        }
        .task(id: node.url ?? "") {
            await loadRemoteImage()
        }
    }

    private var plainRow: some View {
        Button {
            activatePrimary()
        } label: {
            rowLabel
        }
        .buttonStyle(.plain)
        .disabled(isSending && node.action == nil && node.actionId == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Nested one-row List so SwiftUI `.swipeActions` works inside remote_ui ScrollView.
    private var swipeableRow: some View {
        List {
            Button {
                activatePrimary()
            } label: {
                rowLabel
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                ForEach(rowActions) { item in
                    Button(role: item.role == "destructive" ? .destructive : nil) {
                        activateSecondary(item)
                    } label: {
                        Label(
                            item.label,
                            systemImage: item.systemImage ?? (item.role == "destructive" ? "trash" : "ellipsis")
                        )
                    }
                }
            }
            .contextMenu {
                ForEach(rowActions) { item in
                    Button(role: item.role == "destructive" ? .destructive : nil) {
                        activateSecondary(item)
                    } label: {
                        Label(
                            item.label,
                            systemImage: item.systemImage ?? (item.role == "destructive" ? "trash" : "ellipsis")
                        )
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
        }
        .listStyle(.plain)
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 56)
        .frame(minHeight: 56)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var rowLabel: some View {
        HStack(alignment: .center, spacing: 12) {
            leadingIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var leadingIcon: some View {
        if let remoteImage {
            Image(uiImage: remoteImage)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else if let system = node.systemImage, !system.isEmpty {
            Image(systemName: system)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
        } else {
            EmptyView()
        }
    }

    private var accessibilityLabel: String {
        if let subtitle, !subtitle.isEmpty {
            return "\(title), \(subtitle)"
        }
        return title
    }

    private func activatePrimary() {
        if let appAction = node.action, onAppAction != nil {
            onAppAction?(appAction, node)
            return
        }
        guard let actionId = node.actionId, !isSending else { return }
        onAction(actionId, node.id, nil)
    }

    private func activateSecondary(_ item: KBStructuredUISwipeAction) {
        if let appAction = item.action, onAppAction != nil {
            onAppAction?(appAction, node)
            return
        }
        if let actionId = item.actionId, !isSending {
            onAction(actionId, node.id, nil)
        }
    }

    private func loadRemoteImage() async {
        guard let raw = node.url, !raw.isEmpty else { return }
        guard let url = StructuredUIURLPolicy.allowedHTTPURL(from: raw) else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
                return
            }
            if let ui = UIImage(data: data) {
                remoteImage = ui
            }
        } catch {
            // Optional artwork — ignore failures.
        }
    }
}
