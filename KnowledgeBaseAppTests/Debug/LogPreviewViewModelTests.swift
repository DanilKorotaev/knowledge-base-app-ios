import XCTest
@testable import KnowledgeBaseApp

final class LogPreviewViewModelTests: XCTestCase {
    private var logURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let content = """
        2026-05-17 10:00:00 [✅ INFO] [Network] [HTTP] Request req-1
        curl -X GET \\
        --url 'https://kb.test/api'
        HTTP Body: [
        {"ok":true}
        ]

        2026-05-17 10:00:01 [✅ INFO] [Chat] message line
        """
        logURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kb-log-\(UUID().uuidString).log")
        try content.write(to: logURL, atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: logURL)
        try super.tearDownWithError()
    }

    func testLoadsFiltersAndSearch() {
        let viewModel = LogPreviewViewModel(fileURL: logURL)
        viewModel.didLoadView()

        XCTAssertFalse(viewModel.items.isEmpty)
        XCTAssertFalse(viewModel.filters.isEmpty)

        viewModel.searchText = "chat"
        RunLoop.main.run(until: Date().addingTimeInterval(0.35))
        XCTAssertTrue(viewModel.items.allSatisfy { $0.message.lowercased().contains("chat") })

        if let filter = viewModel.filters.first {
            viewModel.selectedFilters = [filter]
        }
        XCTAssertFalse(viewModel.items.isEmpty)
    }

    func testCopyHelpersDetectCurlAndBody() {
        let viewModel = LogPreviewViewModel(fileURL: logURL)
        viewModel.didLoadView()
        guard let item = viewModel.items.first else {
            return XCTFail("missing log item")
        }

        XCTAssertTrue(viewModel.canCopyCurl(for: item))
        XCTAssertTrue(viewModel.canCopyBody(for: item))
        viewModel.didCopyAllRequested(for: item)
        viewModel.didCopyCurlRequested(for: item)
        viewModel.didCopyBodyRequested(for: item)
    }

    func testLongPreviewIsTruncated() {
        let longLine = String(repeating: "x", count: 600)
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kb-long-\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: url) }
        try? "2026-05-17 10:00:00 [✅ INFO] [Common] \n\(longLine)".write(to: url, atomically: true, encoding: .utf8)

        let viewModel = LogPreviewViewModel(fileURL: url)
        viewModel.didLoadView()
        XCTAssertTrue(viewModel.items.first?.preview.hasSuffix("...") == true)
    }
}
