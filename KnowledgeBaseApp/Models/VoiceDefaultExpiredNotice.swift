import Foundation

enum VoiceDefaultExpiredNotice: Equatable {
    case cleared
    case restored(sessionTitle: String)

    var title: String {
        switch self {
        case .cleared:
            L10n.string("voice.default_ended_title")
        case .restored:
            L10n.string("voice.temp_default_ended_title")
        }
    }

    var subtitle: String {
        switch self {
        case .cleared:
            L10n.string("voice.default_ended_subtitle")
        case .restored(let sessionTitle):
            L10n.format("voice.default_restored_subtitle_format", sessionTitle)
        }
    }

    var iconName: String {
        switch self {
        case .cleared:
            "mic.slash"
        case .restored:
            "arrow.uturn.backward.circle.fill"
        }
    }
}
