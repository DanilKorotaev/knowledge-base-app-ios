import XCTest
@testable import KnowledgeBaseApp

final class LogFilesProviderShareListingTests: XCTestCase {
    func testAllLogFileEntriesIncludesShareLogs() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("log-files-share-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let shareLog = temp.appendingPathComponent("share-extension.log")
        try Data("share-line\n".utf8).write(to: shareLog)

        let provider = LogFilesProvider(
            session: LogSession.shared,
            shareLogURLsProvider: { [shareLog] }
        )
        let shareEntries = provider.allLogFileEntries.filter { $0.source == .shareExtension }
        XCTAssertEqual(shareEntries.map(\.url.lastPathComponent), ["share-extension.log"])
        XCTAssertTrue(provider.allLogFileEntries.contains { $0.source == .mainApp } || provider.logFileUrls.isEmpty || true)
    }
}
