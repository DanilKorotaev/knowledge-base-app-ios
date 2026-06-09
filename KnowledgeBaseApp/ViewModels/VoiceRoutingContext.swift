import Foundation

/// Session + KB toggle used when sending voice from the mic bar (aligned with the open chat when navigated).
@Observable
@MainActor
final class VoiceRoutingContext {
    var activeSessionId: String?
    var useKnowledgeBase: Bool = true
    /// When true, finished recordings append to the open chat composer instead of the review sheet.
    var usesComposerDraft: Bool = false
}
