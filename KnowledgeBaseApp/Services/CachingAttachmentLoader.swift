import Foundation

/// Wraps an attachment loader with disk cache (read-through on fetch).
struct CachingAttachmentLoader: KBAttachmentLoaderProtocol {
    let inner: KBAttachmentLoaderProtocol
    let cache: AttachmentDiskCacheProtocol

    func absoluteURL(for downloadPath: String) -> URL? {
        inner.absoluteURL(for: downloadPath)
    }

    func fetchData(from downloadPath: String) async throws -> Data {
        let key = AttachmentCacheKey.normalize(downloadPath: downloadPath)
        if let cached = cache.data(forKey: key) {
            return cached
        }
        let data = try await inner.fetchData(from: downloadPath)
        cache.store(
            data: data,
            key: key,
            metadata: AttachmentCacheKey.metadata(from: downloadPath)
        )
        return data
    }
}
