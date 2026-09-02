import Foundation

/// Shared identifiers for the main app, Widget, and Share Extension.
enum AppGroupIdentifiers {
    static let applicationGroup = "group.com.coredan.KnowledgeBaseApp"

    /// Must match `keychain-access-groups` in app + Share entitlements (`$(AppIdentifierPrefix)` + this suffix).
    static let keychainAccessGroup = "66C9VGAZR5.com.coredan.KnowledgeBaseApp"

    static let composerDraftsFolderName = "KBComposerDrafts"
    static let shareLogsFolderName = "KBShareLogs"
}
