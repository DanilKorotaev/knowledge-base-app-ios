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
        case "button", "checkbox", "radio_group", "select", "text_field":
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
        submit: Bool? = nil
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
    }

    var isSupported: Bool {
        switch type {
        case "vstack", "text", "button", "checkbox", "radio_group", "select", "text_field":
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
}

extension StructuredUIFormValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
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
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected bool, string, or [string]")
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
            }
        }
        guard !parts.isEmpty else { return "[UI] submit" }
        return "[UI] " + parts.joined(separator: "; ")
    }
}
