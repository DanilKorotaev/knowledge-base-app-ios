import Foundation

/// Backend-driven UI document (`structured_ui` on assistant messages).
struct KBStructuredUIDocument: Codable, Equatable, Sendable {
    static let supportedSchemaVersion = 1

    let schemaVersion: Int
    let screen: KBStructuredUINode

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case screen
    }

    var isSupportedByClient: Bool {
        schemaVersion <= Self.supportedSchemaVersion
    }

    /// Buttons or form fields — used to decide if Interactive UI "mode" is still on.
    var hasInteractiveControls: Bool {
        Self.nodeHasInteractiveControls(screen)
    }

    private static func nodeHasInteractiveControls(_ node: KBStructuredUINode) -> Bool {
        switch node.type {
        case "button", "checkbox", "radio_group", "select", "text_field", "date", "time", "slider", "stepper", "confirm":
            return true
        default:
            return node.supportedChildren.contains(where: nodeHasInteractiveControls)
        }
    }
}

struct KBStructuredUIOption: Codable, Equatable, Sendable {
    let id: String
    let label: String
}

struct KBStructuredUINode: Codable, Equatable, Sendable {
    let type: String
    let id: String
    let text: String?
    let label: String?
    let actionId: String?
    let children: [KBStructuredUINode]?
    /// Initial / server-provided value (`bool`, `string`, or string array for multi-select).
    let value: StructuredUIFormValue?
    let placeholder: String?
    let maxLength: Int?
    let options: [KBStructuredUIOption]?
    let multi: Bool?
    /// When true, tapping this button sends local draft `values` with the event.
    let submit: Bool?
    /// Public http(s) URL for `link` / remote `image`.
    let url: String?
    /// Authenticated API download path for `image` / `file` (same as message attachments).
    let downloadURL: String?
    let fileName: String?
    let fileSize: Int?
    /// Accessibility / alt text for `image`.
    let alt: String?
    /// `fit` (default) or `fill` for `image`.
    let contentMode: String?
    /// `info` / `warning` / `tip` / `success` for `callout`.
    let variant: String?
    /// Vertical gap in points for `spacer` (default 8).
    let height: Int?
    /// Step index for `progress` when paired with `total`.
    let current: Int?
    /// Step count for `progress`.
    let total: Int?
    /// Horizontal gap in points for `hstack` (default 8).
    let spacing: Int?
    /// 0…1 fill for `progress` when `current`/`total` are omitted.
    let progressFraction: Double?
    /// Lower bound for `slider` / `stepper`.
    let minimum: Double?
    /// Upper bound for `slider` / `stepper`.
    let maximum: Double?
    /// Step for `slider` / `stepper`.
    let step: Double?

    enum CodingKeys: String, CodingKey {
        case type
        case id
        case text
        case label
        case actionId = "action_id"
        case children
        case value
        case placeholder
        case maxLength = "max_length"
        case options
        case multi
        case submit
        case url
        case downloadURL = "download_url"
        case fileName = "file_name"
        case fileSize = "file_size"
        case alt
        case contentMode = "content_mode"
        case variant
        case height
        case current
        case total
        case spacing
        case minimum = "min"
        case maximum = "max"
        case step
    }

    init(
        type: String,
        id: String,
        text: String? = nil,
        label: String? = nil,
        actionId: String? = nil,
        children: [KBStructuredUINode]? = nil,
        value: StructuredUIFormValue? = nil,
        placeholder: String? = nil,
        maxLength: Int? = nil,
        options: [KBStructuredUIOption]? = nil,
        multi: Bool? = nil,
        submit: Bool? = nil,
        url: String? = nil,
        downloadURL: String? = nil,
        fileName: String? = nil,
        fileSize: Int? = nil,
        alt: String? = nil,
        contentMode: String? = nil,
        variant: String? = nil,
        height: Int? = nil,
        current: Int? = nil,
        total: Int? = nil,
        spacing: Int? = nil,
        progressFraction: Double? = nil,
        minimum: Double? = nil,
        maximum: Double? = nil,
        step: Double? = nil
    ) {
        self.type = type
        self.id = id
        self.text = text
        self.label = label
        self.actionId = actionId
        self.children = children
        self.value = value
        self.placeholder = placeholder
        self.maxLength = maxLength
        self.options = options
        self.multi = multi
        self.submit = submit
        self.url = url
        self.downloadURL = downloadURL
        self.fileName = fileName
        self.fileSize = fileSize
        self.alt = alt
        self.contentMode = contentMode
        self.variant = variant
        self.height = height
        self.current = current
        self.total = total
        self.spacing = spacing
        self.progressFraction = progressFraction
        self.minimum = minimum
        self.maximum = maximum
        self.step = step
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        id = try container.decode(String.self, forKey: .id)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        actionId = try container.decodeIfPresent(String.self, forKey: .actionId)
        children = try container.decodeIfPresent([KBStructuredUINode].self, forKey: .children)
        placeholder = try container.decodeIfPresent(String.self, forKey: .placeholder)
        maxLength = try container.decodeIfPresent(Int.self, forKey: .maxLength)
        options = try container.decodeIfPresent([KBStructuredUIOption].self, forKey: .options)
        multi = try container.decodeIfPresent(Bool.self, forKey: .multi)
        submit = try container.decodeIfPresent(Bool.self, forKey: .submit)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        downloadURL = try container.decodeIfPresent(String.self, forKey: .downloadURL)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        fileSize = try container.decodeIfPresent(Int.self, forKey: .fileSize)
        alt = try container.decodeIfPresent(String.self, forKey: .alt)
        contentMode = try container.decodeIfPresent(String.self, forKey: .contentMode)
        variant = try container.decodeIfPresent(String.self, forKey: .variant)
        height = try container.decodeIfPresent(Int.self, forKey: .height)
        current = try container.decodeIfPresent(Int.self, forKey: .current)
        total = try container.decodeIfPresent(Int.self, forKey: .total)
        spacing = try container.decodeIfPresent(Int.self, forKey: .spacing)
        minimum = try container.decodeIfPresent(Double.self, forKey: .minimum)
        maximum = try container.decodeIfPresent(Double.self, forKey: .maximum)
        step = try container.decodeIfPresent(Double.self, forKey: .step)

        if type == "progress", let fraction = try? container.decode(Double.self, forKey: .value) {
            value = nil
            progressFraction = fraction
        } else if let formValue = try? container.decode(StructuredUIFormValue.self, forKey: .value) {
            value = formValue
            progressFraction = nil
        } else {
            value = nil
            progressFraction = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(actionId, forKey: .actionId)
        try container.encodeIfPresent(children, forKey: .children)
        if let value {
            try container.encode(value, forKey: .value)
        } else if let progressFraction {
            try container.encode(progressFraction, forKey: .value)
        }
        try container.encodeIfPresent(placeholder, forKey: .placeholder)
        try container.encodeIfPresent(maxLength, forKey: .maxLength)
        try container.encodeIfPresent(options, forKey: .options)
        try container.encodeIfPresent(multi, forKey: .multi)
        try container.encodeIfPresent(submit, forKey: .submit)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(downloadURL, forKey: .downloadURL)
        try container.encodeIfPresent(fileName, forKey: .fileName)
        try container.encodeIfPresent(fileSize, forKey: .fileSize)
        try container.encodeIfPresent(alt, forKey: .alt)
        try container.encodeIfPresent(contentMode, forKey: .contentMode)
        try container.encodeIfPresent(variant, forKey: .variant)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(current, forKey: .current)
        try container.encodeIfPresent(total, forKey: .total)
        try container.encodeIfPresent(spacing, forKey: .spacing)
        try container.encodeIfPresent(minimum, forKey: .minimum)
        try container.encodeIfPresent(maximum, forKey: .maximum)
        try container.encodeIfPresent(step, forKey: .step)
    }

    var isSupported: Bool {
        switch type {
        case "vstack", "hstack", "text", "button", "checkbox", "radio_group", "select", "text_field",
             "image", "link", "file", "divider", "callout", "spacer", "progress", "date", "time",
             "slider", "stepper", "confirm", "markdown":
            return true
        default:
            return false
        }
    }

    var supportedChildren: [KBStructuredUINode] {
        children?.filter(\.isSupported) ?? []
    }

    var isSubmitButton: Bool {
        type == "button" && (submit == true)
    }
}

/// Local / wire value for form fields and `ui-events.values`.
enum StructuredUIFormValue: Equatable, Sendable, Hashable {
    case bool(Bool)
    case string(String)
    case strings([String])
    case number(Double)

    var boolValue: Bool {
        if case .bool(let value) = self { return value }
        return false
    }

    var stringValue: String {
        if case .string(let value) = self { return value }
        return ""
    }

    var stringListValue: [String] {
        if case .strings(let value) = self { return value }
        if case .string(let value) = self { return [value] }
        return []
    }

    var numberValue: Double {
        if case .number(let value) = self { return value }
        return 0
    }
}

extension StructuredUIFormValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Int.self) {
            self = .number(Double(value))
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .number(value)
            return
        }
        if let value = try? container.decode([String].self) {
            self = .strings(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        throw DecodingError.typeMismatch(
            StructuredUIFormValue.self,
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected bool, number, string, or [string]")
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .strings(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        }
    }
}

struct KBUIEventResponse: Codable, Equatable, Sendable {
    let screen: KBStructuredUIDocument?
    let messages: [KBMessage]
}

enum StructuredUIFormDraft {
    /// Seed local draft from server node tree (checkbox / radio / select / text_field).
    static func seed(from document: KBStructuredUIDocument) -> [String: StructuredUIFormValue] {
        var values: [String: StructuredUIFormValue] = [:]

        func walk(_ node: KBStructuredUINode) {
            switch node.type {
            case "checkbox":
                values[node.id] = node.value ?? .bool(false)
            case "radio_group", "text_field":
                if let value = node.value {
                    values[node.id] = value
                } else if node.type == "text_field" {
                    values[node.id] = .string("")
                } else if let first = node.options?.first {
                    values[node.id] = .string(first.id)
                }
            case "select":
                if let value = node.value {
                    values[node.id] = value
                } else if node.multi == true {
                    values[node.id] = .strings([])
                } else if let first = node.options?.first {
                    values[node.id] = .string(first.id)
                }
            case "date", "time":
                values[node.id] = node.value ?? .string("")
            case "slider":
                values[node.id] = node.value ?? .number(node.minimum ?? 0)
            case "stepper":
                values[node.id] = node.value ?? .number(node.minimum ?? 0)
            default:
                break
            }
            for child in node.supportedChildren {
                walk(child)
            }
        }

        walk(document.screen)
        return values
    }

    static func summaryLine(from values: [String: StructuredUIFormValue]) -> String {
        let parts = values.keys.sorted().compactMap { key -> String? in
            guard let value = values[key] else { return nil }
            switch value {
            case .bool(let flag):
                return "\(key)=\(flag ? "true" : "false")"
            case .string(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return "\(key)=\(trimmed)"
            case .strings(let list):
                guard !list.isEmpty else { return nil }
                return "\(key)=[\(list.joined(separator: ","))]"
            case .number(let number):
                if number.rounded() == number {
                    return "\(key)=\(Int(number.rounded()))"
                }
                return "\(key)=\(number)"
            }
        }
        guard !parts.isEmpty else { return "[UI] submit" }
        return "[UI] " + parts.joined(separator: "; ")
    }
}
