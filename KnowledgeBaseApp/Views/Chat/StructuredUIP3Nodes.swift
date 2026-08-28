import SwiftUI

enum StructuredUIMarkdownText {
    static func attributedString(from markdown: String) -> AttributedString {
        if let parsed = try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        ) {
            return parsed
        }
        return AttributedString(markdown)
    }
}

struct StructuredUIMarkdownNodeView: View {
    let node: KBStructuredUINode

    var body: some View {
        Text(StructuredUIMarkdownText.attributedString(from: node.text ?? ""))
            .font(.body)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StructuredUISliderNodeView: View {
    let node: KBStructuredUINode
    @Binding var draftValues: [String: StructuredUIFormValue]

    private var minValue: Double { node.minimum ?? 0 }
    private var maxValue: Double { max(node.maximum ?? 100, minValue + 1) }
    private var stepValue: Double { max(node.step ?? 1, 0.01) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = node.label, !label.isEmpty {
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            Slider(value: sliderBinding, in: minValue...maxValue, step: stepValue)
            Text(formattedValue(sliderBinding.wrappedValue))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: {
                let raw = draftValues[node.id]?.numberValue
                    ?? node.value?.numberValue
                    ?? minValue
                return min(max(raw, minValue), maxValue)
            },
            set: { draftValues[node.id] = .number($0) }
        )
    }

    private func formattedValue(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }
}

struct StructuredUIStepperNodeView: View {
    let node: KBStructuredUINode
    @Binding var draftValues: [String: StructuredUIFormValue]

    private var minValue: Int { Int((node.minimum ?? 0).rounded()) }
    private var maxValue: Int { max(Int((node.maximum ?? 100).rounded()), minValue) }
    private var stepValue: Int { max(Int((node.step ?? 1).rounded()), 1) }

    var body: some View {
        Stepper(value: stepperBinding, in: minValue...maxValue, step: stepValue) {
            if let label = node.label, !label.isEmpty {
                Text(label)
            } else {
                Text("\(stepperBinding.wrappedValue)")
            }
        }
    }

    private var stepperBinding: Binding<Int> {
        Binding(
            get: {
                let raw = Int((draftValues[node.id]?.numberValue ?? node.value?.numberValue ?? Double(minValue)).rounded())
                return min(max(raw, minValue), maxValue)
            },
            set: { draftValues[node.id] = .number(Double($0)) }
        )
    }
}

struct StructuredUIConfirmNodeView: View {
    let node: KBStructuredUINode
    var isSending: Bool
    var onAction: (String, String, [String: StructuredUIFormValue]?) -> Void

    @State private var showConfirm = false

    var body: some View {
        Button {
            showConfirm = true
        } label: {
            StructuredUIButtonLabel(title: node.label ?? "")
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(isSending)
        .confirmationDialog(
            node.label ?? L10n.string("structured_ui.confirm_title"),
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button(node.label ?? L10n.string("structured_ui.confirm_action"), role: .destructive) {
                guard let actionId = node.actionId, !isSending else { return }
                onAction(actionId, node.id, nil)
            }
            Button(L10n.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(node.text ?? "")
                .multilineTextAlignment(.leading)
        }
        .accessibilityLabel(node.label ?? "Confirm")
    }
}
