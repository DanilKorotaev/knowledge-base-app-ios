import Foundation

/// Fetch bytes for Structured UI `download_url` — KB API paths use auth; public https uses plain URLSession.
enum StructuredUIResourceFetcher {
    static func shouldUseAuthenticatedLoader(
        for downloadPath: String,
        loader: KBAttachmentLoaderProtocol?
    ) -> Bool {
        let trimmed = downloadPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.hasPrefix("file://") { return false }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            guard let loader,
                  let resourceURL = loader.absoluteURL(for: trimmed),
                  let apiProbe = loader.absoluteURL(for: "api/sessions"),
                  let resourceHost = resourceURL.host?.lowercased(),
                  let apiHost = apiProbe.host?.lowercased() else {
                return false
            }
            return resourceHost == apiHost
        }
        // Relative API paths always go through the auth loader path so a missing
        // loader surfaces as `FetchError.missingLoader` (not invalidURL).
        return StructuredUIURLPolicy.isAllowedDownloadPath(trimmed)
    }

    static func fetchData(
        from downloadPath: String,
        loader: KBAttachmentLoaderProtocol?
    ) async throws -> Data {
        let trimmed = downloadPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw FetchError.emptyPath
        }

        if trimmed.hasPrefix("file://"), let fileURL = URL(string: trimmed), fileURL.isFileURL {
            return try Data(contentsOf: fileURL)
        }

        if trimmed.hasPrefix("/"), FileManager.default.fileExists(atPath: trimmed) {
            return try Data(contentsOf: URL(fileURLWithPath: trimmed))
        }

        if shouldUseAuthenticatedLoader(for: trimmed, loader: loader) {
            guard let loader else { throw FetchError.missingLoader }
            return try await loader.fetchData(from: trimmed)
        }

        guard let url = StructuredUIURLPolicy.allowedHTTPURL(from: trimmed) else {
            throw FetchError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
            throw FetchError.httpStatus(http.statusCode)
        }
        return data
    }

    enum FetchError: Error, LocalizedError {
        case emptyPath
        case missingLoader
        case invalidURL
        case httpStatus(Int)

        var errorDescription: String? {
            switch self {
            case .emptyPath:
                return L10n.string("structured_ui.media_empty_path")
            case .missingLoader:
                return L10n.string("structured_ui.media_load_failed")
            case .invalidURL:
                return L10n.string("structured_ui.media_invalid_url")
            case .httpStatus(let code):
                return String(format: L10n.string("structured_ui.media_http_status_format"), code)
            }
        }
    }
}

enum StructuredUIMediaPath {
    /// Prefer explicit `download_url`, then `url` (agents sometimes swap fields on `file` nodes).
    static func candidates(from node: KBStructuredUINode) -> [String] {
        var paths: [String] = []
        if let download = normalized(node.downloadURL) {
            paths.append(download)
        }
        if let url = normalized(node.url), !paths.contains(url) {
            paths.append(url)
        }
        return paths
    }

    static func primary(from node: KBStructuredUINode) -> String? {
        candidates(from: node).first
    }

    private static func normalized(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
