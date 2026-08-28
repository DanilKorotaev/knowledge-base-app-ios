import SwiftUI
import UIKit
import XCTest
@testable import KnowledgeBaseApp

private struct HostAwareMockLoader: KBAttachmentLoaderProtocol {
    let apiHost: String

    func absoluteURL(for downloadPath: String) -> URL? {
        if downloadPath.hasPrefix("http://") || downloadPath.hasPrefix("https://") {
            return URL(string: downloadPath)
        }
        return URL(string: "https://\(apiHost)/\(downloadPath)")
    }

    func fetchData(from downloadPath: String) async throws -> Data {
        Data("mock".utf8)
    }
}

@MainActor
final class StructuredUIMediaCoverageTests: XCTestCase {
    private var hostingWindows: [UIWindow] = []

    override func tearDown() {
        hostingWindows.removeAll()
        super.tearDown()
    }

    func testResourceFetcherEmptyPathThrows() async {
        do {
            _ = try await StructuredUIResourceFetcher.fetchData(from: "  ", loader: nil)
            XCTFail("Expected emptyPath")
        } catch StructuredUIResourceFetcher.FetchError.emptyPath {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testResourceFetcherReadsFileURL() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sui-fetch-\(UUID().uuidString).txt")
        try Data("hello-sui".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try await StructuredUIResourceFetcher.fetchData(from: url.absoluteString, loader: nil)
        XCTAssertEqual(String(data: data, encoding: .utf8), "hello-sui")
    }

    func testResourceFetcherUsesLoaderForRelativeAPIPath() async throws {
        let loader = HostAwareMockLoader(apiHost: "kb.example.com")
        XCTAssertTrue(
            StructuredUIResourceFetcher.shouldUseAuthenticatedLoader(
                for: "/api/attachments/1/download",
                loader: loader
            )
        )
        let data = try await StructuredUIResourceFetcher.fetchData(
            from: "/api/attachments/1/download",
            loader: loader
        )
        XCTAssertEqual(data, Data("mock".utf8))
    }

    func testResourceFetcherSkipsAuthForExternalHTTPS() {
        let loader = HostAwareMockLoader(apiHost: "kb.example.com")
        XCTAssertFalse(
            StructuredUIResourceFetcher.shouldUseAuthenticatedLoader(
                for: "https://cdn.example.org/guide.pdf",
                loader: loader
            )
        )
    }

    func testResourceFetcherMissingLoaderThrows() async {
        do {
            _ = try await StructuredUIResourceFetcher.fetchData(from: "/api/x", loader: nil)
            XCTFail("Expected missingLoader")
        } catch StructuredUIResourceFetcher.FetchError.missingLoader {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testErrorMessageSanitizesDetailJSON() {
        let error = NSError(
            domain: "test",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: #"{"detail":"Not Found"}"#]
        )
        XCTAssertEqual(
            StructuredUIErrorMessage.userFacing(error),
            L10n.string("structured_ui.media_load_failed")
        )
    }

    func testZoomableImageViewHosts() {
        let image = Self.testImage()
        let host = UIHostingController(rootView: ZoomableImageView(image: image))
        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        attachToWindow(host)
        XCTAssertViewIsHosted(host.view)
    }

    func testFullscreenImageViewerHosts() {
        let host = UIHostingController(
            rootView: FullscreenImageViewer(image: Self.testImage(), onDismiss: {})
        )
        host.view.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        attachToWindow(host)
        XCTAssertViewIsHosted(host.view)
    }

    func testStructuredUILinkNodeViewHosts() {
        let node = KBStructuredUINode(
            type: "link",
            id: "lnk",
            label: "Example",
            url: "https://example.com"
        )
        XCTAssertNotNil(StructuredUIURLPolicy.allowedHTTPURL(from: node.url))
        let host = UIHostingController(rootView: StructuredUILinkNodeView(node: node))
        host.view.frame = CGRect(x: 0, y: 0, width: 300, height: 80)
        attachToWindow(host)
        XCTAssertViewIsHosted(host.view)
    }

    func testStructuredUIImageNodeViewHostsPlaceholder() async {
        let node = KBStructuredUINode(
            type: "image",
            id: "img",
            url: "https://invalid.invalid/not-found.png"
        )
        let host = UIHostingController(
            rootView: StructuredUIImageNodeView(node: node, loader: nil, onFullscreen: nil)
        )
        host.view.frame = CGRect(x: 0, y: 0, width: 300, height: 160)
        attachToWindow(host)
        host.view.layoutIfNeeded()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertViewIsHosted(host.view)
    }

    func testStructuredUIFileNodeViewHosts() {
        let node = KBStructuredUINode(
            type: "file",
            id: "f1",
            label: "Notes",
            downloadURL: "/api/attachments/1/download",
            fileName: "notes.pdf",
            fileSize: 1024
        )
        XCTAssertTrue(StructuredUIURLPolicy.isAllowedDownloadPath(node.downloadURL))
        let host = UIHostingController(
            rootView: StructuredUIFileNodeView(node: node, loader: HostAwareMockLoader(apiHost: "kb.example.com"))
        )
        host.view.frame = CGRect(x: 0, y: 0, width: 300, height: 80)
        attachToWindow(host)
        XCTAssertViewIsHosted(host.view)
    }

    private func attachToWindow(_ host: UIHostingController<some View>) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        hostingWindows.append(window)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }

    private func XCTAssertViewIsHosted(_ view: UIView, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(view.window, "Expected hosted view to be in a window", file: file, line: line)
        XCTAssertFalse(view.isHidden, file: file, line: line)
        XCTAssertGreaterThan(view.bounds.width, 0, file: file, line: line)
    }

    private static func testImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }
}
