import SwiftUI

struct StructuredUIPanelView: View {
    let document: KBStructuredUIDocument
    var isSending: Bool = false
    var isInteractive: Bool = true
    var attachmentLoader: KBAttachmentLoaderProtocol?
    var onFullscreenImage: ((UIImage) -> Void)?
    var onAction: (String, String, [String: StructuredUIFormValue]?) -> Void

    @State private var draftValues: [String: StructuredUIFormValue] = [:]

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
                StructuredUINodeView(
                    node: document.screen,
                    isSending: isSending,
                    isInteractive: isInteractive,
                    attachmentLoader: attachmentLoader,
                    onFullscreenImage: onFullscreenImage,
                    draftValues: $draftValues,
                    onAction: onAction
                )
                .opacity(isSending ? 0.72 : (isInteractive ? 1 : 0.85))
                .allowsHitTesting(isInteractive && !isSending)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("structured_ui.panel_a11y"))
        .accessibilityAddTraits(isSending ? .updatesFrequently : [])
        .onAppear {
            draftValues = StructuredUIFormDraft.seed(from: document)
        }
        .onChange(of: document) { _, newDocument in
            draftValues = StructuredUIFormDraft.seed(from: newDocument)
        }
    }
}

private struct StructuredUINodeView: View {
    let node: KBStructuredUINode
    var isSending: Bool
    var isInteractive: Bool
    var attachmentLoader: KBAttachmentLoaderProtocol?
    var onFullscreenImage: ((UIImage) -> Void)?
    @Binding var draftValues: [String: StructuredUIFormValue]
    var onAction: (String, String, [String: StructuredUIFormValue]?) -> Void

    @ViewBuilder
    var body: some View {
        if !node.isSupported {
            EmptyView()
        } else {
            switch node.type {
            case "vstack":
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(node.supportedChildren.enumerated()), id: \.offset) { _, child in
                        StructuredUINodeView(
                            node: child,
                            isSending: isSending,
                            isInteractive: isInteractive,
                            attachmentLoader: attachmentLoader,
                            onFullscreenImage: onFullscreenImage,
                            draftValues: $draftValues,
                            onAction: onAction
                        )
                    }
                }
            case "hstack":
                HStack(alignment: .center, spacing: CGFloat(node.spacing ?? 8)) {
                    ForEach(Array(node.supportedChildren.enumerated()), id: \.offset) { _, child in
                        StructuredUINodeView(
                            node: child,
                            isSending: isSending,
                            isInteractive: isInteractive,
                            attachmentLoader: attachmentLoader,
                            onFullscreenImage: onFullscreenImage,
                            draftValues: $draftValues,
                            onAction: onAction
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case "text":
                Text(node.text ?? "")
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case "divider":
                Divider()
                    .padding(.vertical, 2)
            case "button":
                Button {
                    guard let actionId = node.actionId, !isSending else { return }
                    if node.isSubmitButton {
                        onAction(actionId, node.id, draftValues)
                    } else {
                        onAction(actionId, node.id, nil)
                    }
                } label: {
                    Text(node.label ?? "")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(node.label ?? "Button")
            case "checkbox":
                Button {
                    let next = !(draftValues[node.id]?.boolValue ?? false)
                    draftValues[node.id] = .bool(next)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: (draftValues[node.id]?.boolValue ?? false) ? "checkmark.square.fill" : "square")
                        Text(node.label ?? node.id)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(node.label ?? node.id)
                .accessibilityAddTraits((draftValues[node.id]?.boolValue ?? false) ? .isSelected : [])
            case "radio_group":
                VStack(alignment: .leading, spacing: 6) {
                    if let label = node.label, !label.isEmpty {
                        Text(label)
                            .font(.subheadline.weight(.semibold))
                    }
                    ForEach(node.options ?? [], id: \.id) { option in
                        Button {
                            draftValues[node.id] = .string(option.id)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: radioSelected(node.id, option.id) ? "largecircle.fill.circle" : "circle")
                                Text(option.label)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.label)
                        .accessibilityAddTraits(radioSelected(node.id, option.id) ? .isSelected : [])
                    }
                }
            case "select":
                VStack(alignment: .leading, spacing: 6) {
                    if let label = node.label, !label.isEmpty {
                        Text(label)
                            .font(.subheadline.weight(.semibold))
                    }
                    if node.multi == true {
                        ForEach(node.options ?? [], id: \.id) { option in
                            Button {
                                let isOn = !(draftValues[node.id]?.stringListValue.contains(option.id) ?? false)
                                var list = draftValues[node.id]?.stringListValue ?? []
                                if isOn {
                                    if !list.contains(option.id) { list.append(option.id) }
                                } else {
                                    list.removeAll { $0 == option.id }
                                }
                                draftValues[node.id] = .strings(list)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(
                                        systemName: (draftValues[node.id]?.stringListValue.contains(option.id) ?? false)
                                            ? "checkmark.square.fill"
                                            : "square"
                                    )
                                    Text(option.label)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Picker(node.label ?? node.id, selection: singleSelectBinding(for: node)) {
                            ForEach(node.options ?? [], id: \.id) { option in
                                Text(option.label).tag(option.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            case "text_field":
                VStack(alignment: .leading, spacing: 4) {
                    if let label = node.label, !label.isEmpty {
                        Text(label)
                            .font(.subheadline.weight(.semibold))
                    }
                    TextField(node.placeholder ?? "", text: textFieldBinding(for: node))
                        .textFieldStyle(.roundedBorder)
                }
            case "image":
                StructuredUIImageNodeView(
                    node: node,
                    loader: attachmentLoader,
                    onFullscreen: onFullscreenImage
                )
            case "link":
                StructuredUILinkNodeView(node: node)
            case "file":
                StructuredUIFileNodeView(node: node, loader: attachmentLoader)
            case "callout":
                StructuredUICalloutNodeView(node: node)
            case "spacer":
                StructuredUISpacerNodeView(node: node)
            case "progress":
                StructuredUIProgressNodeView(node: node)
            case "date":
                StructuredUIDateNodeView(node: node, draftValues: $draftValues)
            case "time":
                StructuredUITimeNodeView(node: node, draftValues: $draftValues)
            default:
                EmptyView()
            }
        }
    }

    private func radioSelected(_ groupId: String, _ optionId: String) -> Bool {
        draftValues[groupId]?.stringValue == optionId
    }

    private func singleSelectBinding(for node: KBStructuredUINode) -> Binding<String> {
        Binding(
            get: {
                if let current = draftValues[node.id]?.stringValue, !current.isEmpty {
                    return current
                }
                return node.options?.first?.id ?? ""
            },
            set: { draftValues[node.id] = .string($0) }
        )
    }

    private func textFieldBinding(for node: KBStructuredUINode) -> Binding<String> {
        Binding(
            get: { draftValues[node.id]?.stringValue ?? "" },
            set: { newValue in
                let limited: String
                if let maxLength = node.maxLength, maxLength > 0 {
                    limited = String(newValue.prefix(maxLength))
                } else {
                    limited = newValue
                }
                draftValues[node.id] = .string(limited)
            }
        )
    }
}
