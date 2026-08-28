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
        if !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
            return loader != nil
        }
        guard let loader,
              let resourceURL = loader.absoluteURL(for: trimmed),
              let apiProbe = loader.absoluteURL(for: "api/sessions"),
              let resourceHost = resourceURL.host?.lowercased(),
              let apiHost = apiProbe.host?.lowercased() else {
            return false
        }
        return resourceHost == apiHost
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

    enum FetchError: Error {
        case emptyPath
        case missingLoader
        case invalidURL
        case httpStatus(Int)
    }
}
