import SwiftUI

enum StructuredUICalloutStyle {
    case info
    case warning
    case tip
    case success

    static func from(variant: String?) -> Self {
        switch variant?.lowercased() {
        case "warning", "warn":
            return .warning
        case "tip":
            return .tip
        case "success":
            return .success
        default:
            return .info
        }
    }

    var iconName: String {
        switch self {
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .tip: "lightbulb.fill"
        case .success: "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .info: .blue
        case .warning: .orange
        case .tip: .purple
        case .success: .green
        }
    }
}

struct StructuredUICalloutNodeView: View {
    let node: KBStructuredUINode

    private var style: StructuredUICalloutStyle {
        StructuredUICalloutStyle.from(variant: node.variant)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: style.iconName)
                .foregroundStyle(style.tint)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                if let label = node.label, !label.isEmpty {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(node.text ?? "")
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(style.tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct StructuredUISpacerNodeView: View {
    let node: KBStructuredUINode

    var body: some View {
        Color.clear
            .frame(height: CGFloat(clampedHeight))
            .accessibilityHidden(true)
    }

    private var clampedHeight: Int {
        let raw = node.height ?? 8
        return min(max(raw, 4), 64)
    }
}

struct StructuredUIProgressNodeView: View {
    let node: KBStructuredUINode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = node.label, !label.isEmpty {
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            if let current = node.current, let total = node.total, total > 0 {
                ProgressView(value: Double(min(current, total)), total: Double(total))
                Text("\(min(current, total)) / \(total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                let fraction = min(max(node.progressFraction ?? 0, 0), 1)
                ProgressView(value: fraction)
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(L10n.string("structured_ui.progress_readonly"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

enum StructuredUIDateTimeFormat {
    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

struct StructuredUIDateNodeView: View {
    let node: KBStructuredUINode
    @Binding var draftValues: [String: StructuredUIFormValue]
    var isInteractive: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = node.label, !label.isEmpty {
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            if isInteractive {
                DatePicker(
                    node.label ?? node.id,
                    selection: dateBinding,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            } else {
                Text(displayValue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var displayValue: String {
        let raw = draftValues[node.id]?.stringValue ?? node.value?.stringValue ?? ""
        return raw.isEmpty ? "—" : raw
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: {
                let raw = draftValues[node.id]?.stringValue ?? node.value?.stringValue ?? ""
                if let parsed = StructuredUIDateTimeFormat.date.date(from: raw) {
                    return parsed
                }
                return Date()
            },
            set: { newDate in
                draftValues[node.id] = .string(StructuredUIDateTimeFormat.date.string(from: newDate))
            }
        )
    }
}

struct StructuredUITimeNodeView: View {
    let node: KBStructuredUINode
    @Binding var draftValues: [String: StructuredUIFormValue]
    var isInteractive: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = node.label, !label.isEmpty {
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            if isInteractive {
                DatePicker(
                    node.label ?? node.id,
                    selection: timeBinding,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.compact)
            } else {
                Text(displayValue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var displayValue: String {
        let raw = draftValues[node.id]?.stringValue ?? node.value?.stringValue ?? ""
        return raw.isEmpty ? "—" : raw
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                let raw = draftValues[node.id]?.stringValue ?? node.value?.stringValue ?? ""
                if let parsed = StructuredUIDateTimeFormat.time.date(from: raw) {
                    return parsed
                }
                return Date()
            },
            set: { newDate in
                draftValues[node.id] = .string(StructuredUIDateTimeFormat.time.string(from: newDate))
            }
        )
    }
}
