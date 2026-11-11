import Foundation

enum CrashLogUploadQueue {
    static let maxCount = 5

    static func enqueue(_ sessionID: String, into ids: [String]) -> [String] {
        let trimmed = sessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ids }
        var next = ids.filter { $0 != trimmed }
        next.append(trimmed)
        if next.count > maxCount {
            next.removeFirst(next.count - maxCount)
        }
        return next
    }
}
