import Foundation

/// BGTask identifiers declared in Info.plist `BGTaskSchedulerPermittedIdentifiers`.
enum HealthBackgroundTaskIdentifier {
    static let refresh = "com.coredan.KnowledgeBaseApp.health-sync.refresh"
    static let processing = "com.coredan.KnowledgeBaseApp.health-sync.processing"

    static let permitted: [String] = [refresh, processing]
}
