import Foundation

/// A file touched by the assistant or sync; backend contract TBD (`GET …/api/files/changes`).
struct KBChangedFile: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let path: String
    /// e.g. `modified`, `created`
    let changeKind: String
    let beforeText: String?
    let afterText: String?
}
