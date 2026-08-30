import XCTest
@testable import KnowledgeBaseApp

final class AttachmentDiskCacheTests: XCTestCase {
    private var cacheDir: URL!
    private var cache: FileAttachmentDiskCache!

    override func setUp() {
        super.setUp()
        cacheDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("attachment-cache-\(UUID().uuidString)", isDirectory: true)
        cache = FileAttachmentDiskCache(baseURL: cacheDir, maxBytes: 200)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: cacheDir)
        super.tearDown()
    }

    func testStoreAndReadHit() {
        let key = "api/sessions/1/attachments/2/file"
        let data = Data(repeating: 0xAB, count: 40)
        cache.store(
            data: data,
            key: key,
            metadata: CachedAttachmentMetadata(fileName: "photo.jpg", mimeType: "image/jpeg", sessionId: "1", messageId: "2")
        )

        XCTAssertEqual(cache.data(forKey: key), data)
        XCTAssertEqual(cache.allEntries().count, 1)
        XCTAssertEqual(cache.totalByteSize(), 40)
    }

    func testRemoveSingleEntry() {
        let key = "api/sessions/9/attachments/1/file"
        cache.store(data: Data([1, 2, 3]), key: key, metadata: CachedAttachmentMetadata(fileName: nil, mimeType: nil, sessionId: nil, messageId: nil))
        cache.remove(key: key)
        XCTAssertNil(cache.data(forKey: key))
        XCTAssertTrue(cache.allEntries().isEmpty)
    }

    func testLRUEvictsOldestWhenOverLimit() throws {
        cache.store(data: Data(repeating: 1, count: 80), key: "a", metadata: CachedAttachmentMetadata(fileName: "a", mimeType: nil, sessionId: nil, messageId: nil))
        Thread.sleep(forTimeInterval: 0.01)
        cache.store(data: Data(repeating: 2, count: 80), key: "b", metadata: CachedAttachmentMetadata(fileName: "b", mimeType: nil, sessionId: nil, messageId: nil))
        Thread.sleep(forTimeInterval: 0.01)
        cache.store(data: Data(repeating: 3, count: 80), key: "c", metadata: CachedAttachmentMetadata(fileName: "c", mimeType: nil, sessionId: nil, messageId: nil))

        let keys = Set(cache.allEntries().map(\.cacheKey))
        XCTAssertFalse(keys.contains("a"))
        XCTAssertTrue(keys.contains("b"))
        XCTAssertTrue(keys.contains("c"))
        XCTAssertLessThanOrEqual(cache.totalByteSize(), 200)
    }

    func testAttachmentCacheKey_parsesSessionAndAttachmentIds() {
        let meta = AttachmentCacheKey.metadata(
            from: "/api/sessions/42/attachments/7/file",
            fileName: "voice.m4a",
            mimeType: "audio/mp4"
        )
        XCTAssertEqual(meta.sessionId, "42")
        XCTAssertEqual(meta.messageId, "7")
        XCTAssertEqual(meta.fileName, "voice.m4a")
    }

    func testFileURLReturnsStoredPath() {
        let key = "api/sessions/1/attachments/2/file"
        cache.store(
            data: Data([0x01, 0x02]),
            key: key,
            metadata: CachedAttachmentMetadata(fileName: "clip.mp4", mimeType: "video/mp4", sessionId: "1", messageId: "2")
        )
        let url = cache.fileURL(forKey: key)
        XCTAssertNotNil(url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url?.path ?? ""))
    }
}

final class CachingAttachmentLoaderTests: XCTestCase {
    func testSecondFetchUsesCache() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("caching-loader-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let disk = FileAttachmentDiskCache(baseURL: dir)
        let inner = CountingAttachmentLoader(payload: Data([0xFF, 0xD8, 0xFF]))
        let loader = CachingAttachmentLoader(inner: inner, cache: disk)
        let path = "/api/sessions/1/attachments/1/file"

        _ = try await loader.fetchData(from: path)
        _ = try await loader.fetchData(from: path)

        XCTAssertEqual(inner.fetchCount, 1)
        XCTAssertEqual(disk.allEntries().count, 1)
    }
}

private final class CountingAttachmentLoader: KBAttachmentLoaderProtocol, @unchecked Sendable {
    let payload: Data
    private(set) var fetchCount = 0
    private let lock = NSLock()

    init(payload: Data) {
        self.payload = payload
    }

    func absoluteURL(for downloadPath: String) -> URL? {
        URL(string: "https://example.test/\(downloadPath)")
    }

    func fetchData(from downloadPath: String) async throws -> Data {
        lock.lock()
        fetchCount += 1
        lock.unlock()
        return payload
    }
}
