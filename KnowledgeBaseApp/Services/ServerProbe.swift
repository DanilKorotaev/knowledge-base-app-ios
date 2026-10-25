import Foundation

/// Lightweight reachability check for a KB App API base URL (Nextcloud-style “enter server first”).
struct ServerProbeResult: Equatable, Sendable {
    var openSignup: Bool
}

enum ServerProbeError: LocalizedError, Equatable {
    case invalidURL
    case unreachable(String?)
    case missingHealth
    case missingAuthEndpoints

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "auth.error_bad_url")
        case let .unreachable(detail):
            return detail ?? String(localized: "auth.error_server_unreachable")
        case .missingHealth:
            return String(localized: "auth.error_server_not_kb")
        case .missingAuthEndpoints:
            return String(localized: "auth.error_server_not_kb")
        }
    }
}

enum ServerProbe {
    static func normalizeBaseURL(_ raw: String) -> URL? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if !value.contains("://") {
            value = "https://\(value)"
        }
        while value.hasSuffix("/") {
            value.removeLast()
        }
        guard let url = URL(string: value), url.host != nil else { return nil }
        return url
    }

    /// Confirms `/health` and `/api/auth/signup-status` respond.
    static func probe(
        baseURL: URL,
        urlSession: URLSession = .shared
    ) async throws -> ServerProbeResult {
        try await requireOK(url: baseURL.appendingPathComponent("health"), session: urlSession)
        let authClient = URLSessionAuthAPIClient(baseURL: baseURL, urlSession: urlSession)
        do {
            let status = try await authClient.signupStatus()
            return ServerProbeResult(openSignup: status.openSignup)
        } catch {
            throw ServerProbeError.missingAuthEndpoints
        }
    }

    private static func requireOK(url: URL, session: URLSession) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                throw ServerProbeError.missingHealth
            }
            // Prefer JSON health shape when present; accept any 2xx.
            if !data.isEmpty,
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = obj["status"] as? String,
               status.lowercased() != "ok",
               status.lowercased() != "healthy" {
                throw ServerProbeError.missingHealth
            }
        } catch let error as ServerProbeError {
            throw error
        } catch {
            throw ServerProbeError.unreachable(error.localizedDescription)
        }
    }
}
