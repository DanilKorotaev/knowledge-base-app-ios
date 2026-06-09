import Foundation

/// Computes how much of a streaming target string to reveal per animation step.
enum StreamTextRevealEngine {
    static func nextRevealEndIndex(in target: String, revealedCount: Int, maxStep: Int = 10) -> Int {
        guard revealedCount < target.count else { return revealedCount }
        let remaining = target.count - revealedCount
        let stepLimit = min(max(1, maxStep), remaining)

        var end = revealedCount
        var stepped = 0
        var index = target.index(target.startIndex, offsetBy: revealedCount)

        while stepped < stepLimit && index < target.endIndex {
            let character = target[index]
            index = target.index(after: index)
            stepped += 1
            end = revealedCount + stepped

            if character.isWhitespace || character.isNewline {
                break
            }
            if character == "." || character == "!" || character == "?" || character == ";" {
                break
            }
        }

        return end
    }
}
