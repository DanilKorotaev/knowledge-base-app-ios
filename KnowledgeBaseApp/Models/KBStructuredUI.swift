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
}

struct KBStructuredUINode: Codable, Equatable, Sendable {
    let type: String
    let id: String
    let text: String?
    let label: String?
    let actionId: String?
    let children: [KBStructuredUINode]?

    enum CodingKeys: String, CodingKey {
        case type
        case id
        case text
        case label
        case actionId = "action_id"
        case children
    }

    var isSupported: Bool {
        switch type {
        case "vstack", "text", "button":
            return true
        default:
            return false
        }
    }

    var supportedChildren: [KBStructuredUINode] {
        children?.filter(\.isSupported) ?? []
    }
}

struct KBUIEventResponse: Codable, Equatable, Sendable {
    let screen: KBStructuredUIDocument
    let messages: [KBMessage]
}
