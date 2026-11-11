import Foundation

enum CrashLogUploadCoordinator {
    private static let pausedKey = "kb.logger.crashLogUploadPausedByServer"

    static func handleLaunch(didCrash: Bool, previousSessionId: String?) {
        if didCrash, let previousSessionId {
            remember(previousSessionId)
        }
        guard KBLoggerSettings.shared.isCrashLogUploadEnabled else { return }
        guard !isPausedByServer else { return }
        let pending = load()
        guard !pending.isEmpty else { return }
        Task {
            await flush(pending)
        }
    }

    static func setUploadEnabled(_ enabled: Bool) {
        guard enabled else { return }
        UserDefaults.standard.removeObject(forKey: pausedKey)
        let pending = load()
        guard !pending.isEmpty else { return }
        Task {
            await flush(pending)
        }
    }

    private static var isPausedByServer: Bool {
        UserDefaults.standard.bool(forKey: pausedKey)
    }

    private static func remember(_ sessionID: String) {
        let next = CrashLogUploadQueue.enqueue(sessionID, into: load())
        store(next)
    }

    private static func load() -> [String] {
        UserDefaultsService.shared.string(forKey: .loggerPendingCrashSessions)
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
    }

    private static func store(_ ids: [String]) {
        let data = (try? JSONEncoder().encode(ids)) ?? Data("[]".utf8)
        let text = String(data: data, encoding: .utf8) ?? "[]"
        UserDefaultsService.shared.set(text, forKey: .loggerPendingCrashSessions)
    }

    private static func flush(_ pending: [String]) async {
        guard let baseURL = AppConfiguration.url(for: AppConfiguration.Keys.apiBaseURL),
              let token = KeychainTokenStore.token() else {
            return
        }
        var remaining = pending
        for sessionID in pending {
            guard let fileURL = logFile(sessionID: sessionID) else {
                remaining.removeAll { $0 == sessionID }
                continue
            }
            let outcome = await CrashLogUploader.upload(
                fileURL: fileURL,
                logSession: sessionID,
                baseURL: baseURL,
                token: token
            )
            switch outcome {
            case .uploaded, .drop:
                remaining.removeAll { $0 == sessionID }
            case .pausedByServer:
                UserDefaults.standard.set(true, forKey: pausedKey)
                store(remaining)
                return
            case .retryLater:
                store(remaining)
                return
            }
        }
        store(remaining)
    }

    private static func logFile(sessionID: String) -> URL? {
        LogFilesProvider.shared.logFileUrls.first { $0.lastPathComponent.hasPrefix(sessionID) }
    }
}

enum CrashLogUploadOutcome {
    case uploaded
    case drop
    case pausedByServer
    case retryLater
}

enum CrashLogUploader {
    static let maxBytes = 4 * 1024 * 1024

    static func upload(
        fileURL: URL,
        logSession: String,
        baseURL: URL,
        token: String,
        session: URLSession = .shared
    ) async -> CrashLogUploadOutcome {
        guard let body = try? Data(contentsOf: fileURL) else { return .drop }
        let payload = body.count > maxBytes ? body.suffix(maxBytes) : body
        let boundary = "kb-crash-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appendingPathComponent("api/crash-logs"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipart(
            boundary: boundary,
            logSession: logSession,
            fileData: Data(payload)
        )
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200 ... 299).contains(status) {
                return .uploaded
            }
            if status == 403, errorCode(data) == "crash_logs_disabled" {
                return .pausedByServer
            }
            if status == 400 || status == 413 || status == 401 {
                return .drop
            }
            return .retryLater
        } catch {
            return .retryLater
        }
    }

    static func multipart(boundary: String, logSession: String, fileData: Data) -> Data {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        var data = Data()
        let crlf = "\r\n"
        func field(_ name: String, _ value: String) {
            data.append(Data("--\(boundary)\(crlf)".utf8))
            data.append(Data("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)".utf8))
            data.append(Data("\(value)\(crlf)".utf8))
        }
        field("log_session", logSession)
        field("app_version", version)
        field("app_build", build)
        data.append(Data("--\(boundary)\(crlf)".utf8))
        data.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(logSession).log\"\(crlf)".utf8))
        data.append(Data("Content-Type: text/plain\(crlf)\(crlf)".utf8))
        data.append(fileData)
        data.append(Data("\(crlf)--\(boundary)--\(crlf)".utf8))
        return data
    }

    private static func errorCode(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any] else {
            return nil
        }
        return error["code"] as? String
    }
}
