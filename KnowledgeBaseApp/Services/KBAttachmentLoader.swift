import Foundation
import UIKit

/// Authenticated download for KB App API attachment paths (`download_url` from messages).
protocol KBAttachmentLoaderProtocol: Sendable {
    func absoluteURL(for downloadPath: String) -> URL?
    func fetchData(from downloadPath: String) async throws -> Data
}

struct StubAttachmentLoader: KBAttachmentLoaderProtocol {
    func absoluteURL(for downloadPath: String) -> URL? {
        URL(string: downloadPath)
    }

    func fetchData(from downloadPath: String) async throws -> Data {
        if downloadPath.contains("demo-photo") {
            return Self.placeholderJPEG()
        }
        throw KnowledgeBaseAPIError.invalidResponse(statusCode: 404, apiMessage: "Stub attachment")
    }

    private static func placeholderJPEG() -> Data {
        let size = CGSize(width: 120, height: 80)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.85) ?? Data()
    }
}
