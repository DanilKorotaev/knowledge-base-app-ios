import AppIntents
import Foundation

/// Opens the app via `knowledgebase://record` using `OpenURLIntent` (iOS 18+).
public struct StartVoiceRecordingIntent: AppIntent {
    public static var title: LocalizedStringResource = "Быстрая запись"
    public static var description = IntentDescription("Открыть Knowledge Base для голосового запроса")
    public static var isDiscoverable: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & OpensIntent {
        let url = URL(string: "knowledgebase://record")!
        return .result(opensIntent: OpenURLIntent(url))
    }
}
