import Foundation

struct LogFileEntry: Identifiable, Equatable {
    enum Source: String, Equatable {
        case mainApp
        case shareExtension
    }

    let url: URL
    let source: Source

    var id: String { "\(source.rawValue):\(url.path)" }
}

final class LogFilesProvider {
    static let shared = LogFilesProvider(session: LogSession.shared)

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH_mm_ss"
        return formatter
    }()

    private let session: LogSession
    private let directoryName = "Logs"
    private let fileManager: FileManager
    private let shareLogURLsProvider: () -> [URL]

    private(set) var maxFileToStorage: Int {
        get {
            let stored = UserDefaultsService.shared.object(forKey: .loggerMaxLogFiles) as? Int
            return stored ?? Constants.maxFilesDefault
        }
        set {
            UserDefaultsService.shared.set(newValue, forKey: .loggerMaxLogFiles)
            removeLogFilesIfNeeded()
        }
    }

    var currentSessionLogFilePath: URL? {
        let dateText = Self.formatter.string(from: session.startedAt)
        let fileName = "\(session.id) \(dateText)"
        return documentsDirectory(with: directoryName)?
            .appendingPathComponent(fileName)
            .appendingPathExtension("log")
    }

    /// Main-app session logs only (Documents). Used by shake-to-send / retention.
    var logFileUrls: [URL] {
        guard let directory = documentsDirectory(with: directoryName),
              let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return [] }

        return files.compactMap { url -> (URL, Date)? in
            guard let date = try? fileManager.attributesOfItem(atPath: url.path)[.creationDate] as? Date else {
                return nil
            }
            return (url, date)
        }
        .sorted { $0.1 > $1.1 }
        .map(\.0)
    }

    /// Main-app + Share Extension logs for Debug → Files.
    var allLogFileEntries: [LogFileEntry] {
        let app = logFileUrls.map { LogFileEntry(url: $0, source: .mainApp) }
        let share = shareLogURLsProvider().map { LogFileEntry(url: $0, source: .shareExtension) }
        return app + share
    }

    init(
        session: LogSession,
        fileManager: FileManager = .default,
        shareLogURLsProvider: @escaping () -> [URL] = { ShareLogPaths.existingLogFileURLs() }
    ) {
        self.session = session
        self.fileManager = fileManager
        self.shareLogURLsProvider = shareLogURLsProvider
        removeLogFilesIfNeeded()
    }

    func setMaxFileToStorage(_ maxCount: Int) throws {
        guard maxCount >= 0 else { throw LogFilesProviderError.invalidMaxCount }
        maxFileToStorage = maxCount
    }

    private func removeLogFilesIfNeeded() {
        let limit = max(1, maxFileToStorage)
        let files = logFileUrls
        guard files.count > limit else { return }
        files.suffix(from: limit).forEach { try? fileManager.removeItem(at: $0) }
    }

    private func documentsDirectory(with name: String) -> URL? {
        guard var documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        if let bundle = Bundle.main.bundleIdentifier {
            documents.appendPathComponent(bundle)
        }
        documents.appendPathComponent(name)
        if !fileManager.fileExists(atPath: documents.path) {
            do {
                try fileManager.createDirectory(at: documents, withIntermediateDirectories: true)
            } catch {
                return nil
            }
        }
        return documents
    }

    private enum Constants {
        static let maxFilesDefault = 10
    }

    enum LogFilesProviderError: Error {
        case invalidMaxCount
    }
}
