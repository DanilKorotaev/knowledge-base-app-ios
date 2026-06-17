import Foundation

enum VoiceDefaultExpiredNotice: Equatable {
    case cleared
    case restored(sessionTitle: String)

    var title: String {
        switch self {
        case .cleared:
            "Voice default ended"
        case .restored:
            "Temporary default ended"
        }
    }

    var subtitle: String {
        switch self {
        case .cleared:
            "Recordings open the review sheet until you pick a new default session."
        case .restored(let sessionTitle):
            "Voice routing is back on “\(sessionTitle)”."
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
