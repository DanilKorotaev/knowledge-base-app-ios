import Foundation

/// Paths for Share Extension log files inside the App Group container.
enum ShareLogPaths {
    static func logsDirectory(fileManager: FileManager = .default) -> URL? {
        guard let root = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroupIdentifiers.applicationGroup
        ) else {
            return nil
        }
        let dir = root.appendingPathComponent(AppGroupIdentifiers.shareLogsFolderName, isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func currentLogFileURL(fileManager: FileManager = .default) -> URL? {
        logsDirectory(fileManager: fileManager)?
            .appendingPathComponent("share-extension.log", isDirectory: false)
    }

    static func existingLogFileURLs(fileManager: FileManager = .default) -> [URL] {
        guard let dir = logsDirectory(fileManager: fileManager),
              let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
        else {
            return []
        }
        return files
            .filter { $0.pathExtension.lowercased() == "log" }
            .compactMap { url -> (URL, Date)? in
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                let date = values?.contentModificationDate
                    ?? (try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)
                guard let date else { return nil }
                return (url, date)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }
}
