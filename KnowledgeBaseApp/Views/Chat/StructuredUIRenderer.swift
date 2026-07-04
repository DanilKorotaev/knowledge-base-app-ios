import SwiftUI

struct StructuredUIPanelView: View {
    let document: KBStructuredUIDocument
    var isSending: Bool = false
    var onAction: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !document.isSupportedByClient {
                Label(
                    L10n.string("structured_ui.unsupported_schema"),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                StructuredUINodeView(node: document.screen, isSending: isSending, onAction: onAction)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("structured_ui.panel_a11y"))
    }
}

private struct StructuredUINodeView: View {
    let node: KBStructuredUINode
    var isSending: Bool
    var onAction: (String, String) -> Void

    @ViewBuilder
    var body: some View {
        if !node.isSupported {
            EmptyView()
        } else {
            switch node.type {
            case "vstack":
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(node.supportedChildren.enumerated()), id: \.offset) { _, child in
                        StructuredUINodeView(node: child, isSending: isSending, onAction: onAction)
                    }
                }
            case "text":
                Text(node.text ?? "")
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case "button":
                Button {
                    guard let actionId = node.actionId, !isSending else { return }
                    onAction(actionId, node.id)
                } label: {
                    Text(node.label ?? "")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSending)
                .accessibilityLabel(node.label ?? "Button")
            default:
                EmptyView()
            }
        }
    }
}
