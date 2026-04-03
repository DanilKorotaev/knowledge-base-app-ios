import XCTest
@testable import KnowledgeBaseApp

final class FilesAPIClientTests: XCTestCase {
    func testStubFetchReturnsDemoItems() async throws {
        let client = StubFilesAPIClient()
        let files = try await client.fetchChangedFiles()
        XCTAssertEqual(files.count, 2)
        XCTAssertEqual(files.first?.path, "notes/meeting.md")
    }

    func testStubRevertRemovesItem() async throws {
        let client = StubFilesAPIClient()
        var files = try await client.fetchChangedFiles()
        let id = try XCTUnwrap(files.first?.id)
        try await client.revertFile(id: id)
        files = try await client.fetchChangedFiles()
        XCTAssertEqual(files.count, 1)
    }
}
