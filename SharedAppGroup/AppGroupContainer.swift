import Foundation

/// App Group container helpers shared by the main app and extensions.
enum AppGroupContainer {
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupIdentifiers.applicationGroup)
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupIdentifiers.applicationGroup)
    }

    /// Directory for composer drafts visible to the Share Extension and main app.
    static func composerDraftsDirectory(fileManager: FileManager = .default) -> URL {
        if let root = containerURL {
            let drafts = root.appendingPathComponent(AppGroupIdentifiers.composerDraftsFolderName, isDirectory: true)
            try? fileManager.createDirectory(at: drafts, withIntermediateDirectories: true)
            migrateLegacyComposerDraftsIfNeeded(to: drafts, fileManager: fileManager)
            return drafts
        }

        let fallback = (fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory)
            .appendingPathComponent(AppGroupIdentifiers.composerDraftsFolderName, isDirectory: true)
        try? fileManager.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }

    /// Copies Application Support drafts into the App Group once (main app sandbox → shared).
    static func migrateLegacyComposerDraftsIfNeeded(
        to destination: URL,
        fileManager: FileManager = .default,
        legacyRoot: URL? = nil
    ) {
        let marker = destination.appendingPathComponent(".migrated-from-app-support", isDirectory: false)
        guard !fileManager.fileExists(atPath: marker.path) else { return }

        let resolvedLegacy = legacyRoot
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(AppGroupIdentifiers.composerDraftsFolderName, isDirectory: true)
        defer {
            try? Data().write(to: marker, options: .atomic)
        }
        guard let resolvedLegacy, fileManager.fileExists(atPath: resolvedLegacy.path) else { return }

        let legacyItems = (try? fileManager.contentsOfDirectory(
            at: resolvedLegacy,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for item in legacyItems {
            let dest = destination.appendingPathComponent(item.lastPathComponent)
            if fileManager.fileExists(atPath: dest.path) { continue }
            try? fileManager.copyItem(at: item, to: dest)
        }
    }

    /// Moves a UserDefaults value from `.standard` into the App Group suite when missing there.
    static func migrateUserDefaultsValue(forKey key: String) {
        guard let shared = sharedDefaults else { return }
        if shared.object(forKey: key) != nil { return }
        guard let value = UserDefaults.standard.object(forKey: key) else { return }
        shared.set(value, forKey: key)
    }
}
