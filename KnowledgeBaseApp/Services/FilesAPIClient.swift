import Foundation

protocol FilesAPIClientProtocol: Sendable {
    func fetchChangedFiles() async throws -> [KBChangedFile]
    func revertFile(id: String) async throws
}

enum FilesAPIError: Error, Equatable {
    case invalidResponse(statusCode: Int, apiMessage: String? = nil)
    case decodingFailed
}

/// Demo list + in-memory revert until KB App API exposes file operations.
final class StubFilesAPIClient: FilesAPIClientProtocol, @unchecked Sendable {
    private var items: [KBChangedFile]

    init() {
        items = [
            KBChangedFile(
                id: "stub-1",
                path: "notes/meeting.md",
                changeKind: "modified",
                beforeText: "# Meeting\n\n- Old point",
                afterText: "# Meeting\n\n- New point\n- Action item"
            ),
            KBChangedFile(
                id: "stub-2",
                path: "kb/facts.txt",
                changeKind: "modified",
                beforeText: "Version: 1",
                afterText: "Version: 2\nUpdated by assistant."
            ),
        ]
    }

    func fetchChangedFiles() async throws -> [KBChangedFile] {
        items
    }

    func revertFile(id: String) async throws {
        items.removeAll { $0.id == id }
    }
}
