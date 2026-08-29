import SwiftUI

struct StructuredUIMarkdownNodeView: View {
    let node: KBStructuredUINode

    var body: some View {
        MarkdownTextBlockView(text: node.text ?? "")
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StructuredUISliderNodeView: View {
    let node: KBStructuredUINode
    @Binding var draftValues: [String: StructuredUIFormValue]
    var isInteractive: Bool = true

    private var minValue: Double { node.minimum ?? 0 }
    private var maxValue: Double { max(node.maximum ?? 100, minValue + 1) }
    private var stepValue: Double { max(node.step ?? 1, 0.01) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = node.label, !label.isEmpty {
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            if isInteractive {
                Slider(value: sliderBinding, in: minValue...maxValue, step: stepValue)
            }
            Text(formattedValue(sliderBinding.wrappedValue))
                .font(.caption.monospacedDigit())
                .foregroundStyle(isInteractive ? .secondary : .primary)
                .padding(.vertical, isInteractive ? 0 : 8)
                .padding(.horizontal, isInteractive ? 0 : 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isInteractive ? Color.clear : Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .accessibilityElement(children: .combine)
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
    var isInteractive: Bool = true

    private var minValue: Int { Int((node.minimum ?? 0).rounded()) }
    private var maxValue: Int { max(Int((node.maximum ?? 100).rounded()), minValue) }
    private var stepValue: Int { max(Int((node.step ?? 1).rounded()), 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let label = node.label, !label.isEmpty {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(formattedValue(stepperBinding.wrappedValue))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isInteractive ? Color.secondary.opacity(0.14) : Color.accentColor.opacity(0.18))
                    .clipShape(Capsule())
                    .accessibilityLabel(L10n.string("structured_ui.stepper_value_a11y"))
            }
            if isInteractive {
                Stepper(
                    L10n.string("structured_ui.stepper_adjust_a11y"),
                    value: stepperBinding,
                    in: minValue...maxValue,
                    step: stepValue
                )
                .labelsHidden()
            }
        }
        .accessibilityElement(children: .contain)
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

    private func formattedValue(_ value: Int) -> String {
        String(value)
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
