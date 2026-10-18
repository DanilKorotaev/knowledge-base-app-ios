import SwiftUI
import UIKit

/// Tappable list cell: optional leading SF Symbol / remote image, title, subtitle, chevron.
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

    var body: some View {
        Button {
            activate()
        } label: {
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
        .buttonStyle(.plain)
        .disabled(isSending && node.action == nil && node.actionId == nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .task(id: node.url ?? "") {
            await loadRemoteImage()
        }
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

    private func activate() {
        if let appAction = node.action, onAppAction != nil {
            onAppAction?(appAction, node)
            return
        }
        guard let actionId = node.actionId, !isSending else { return }
        onAction(actionId, node.id, nil)
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
