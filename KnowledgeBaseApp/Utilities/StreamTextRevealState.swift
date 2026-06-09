import Foundation

/// Drives incremental typewriter reveal without restarting when SSE target text grows.
@MainActor
final class StreamTextRevealState {
    private(set) var revealedText = ""
    var targetText = ""
    var isFinishing = false
    var onGrowth: (() -> Void)?
    var onComplete: (() -> Void)?

    private var revealTask: Task<Void, Never>?
    private var didSignalComplete = false
    private var stepsSinceScroll = 0

    func updateTarget(_ text: String, finishing: Bool) {
        targetText = text
        isFinishing = finishing
        if finishing {
            didSignalComplete = false
        }
        guard !targetText.isEmpty else {
            revealedText = ""
            return
        }
        if !targetText.hasPrefix(revealedText) {
            revealedText = String(targetText.prefix(commonPrefixLength(revealedText, targetText)))
        }
        ensureRevealLoop()
    }

    func reset() {
        revealTask?.cancel()
        revealTask = nil
        targetText = ""
        revealedText = ""
        didSignalComplete = false
        stepsSinceScroll = 0
    }

    private func ensureRevealLoop() {
        guard revealTask == nil else { return }
        guard !targetText.isEmpty else { return }

        revealTask = Task { [weak self] in
            await self?.runRevealLoop()
        }
    }

    private func runRevealLoop() async {
        defer { revealTask = nil }

        while !Task.isCancelled {
            if revealedText.count < targetText.count {
                let fast = isFinishing
                let intervalMs = fast ? 6 : 30
                let maxStep = fast ? 32 : 10
                let nextEnd = StreamTextRevealEngine.nextRevealEndIndex(
                    in: targetText,
                    revealedCount: revealedText.count,
                    maxStep: maxStep
                )
                revealedText = String(targetText.prefix(nextEnd))
                stepsSinceScroll += 1
                if stepsSinceScroll >= 2 {
                    onGrowth?()
                    stepsSinceScroll = 0
                }
                try? await Task.sleep(for: .milliseconds(intervalMs))
                continue
            }

            if isFinishing {
                revealedText = targetText
                onGrowth?()
                signalCompleteIfNeeded()
                break
            }

            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    private func signalCompleteIfNeeded() {
        guard isFinishing, !didSignalComplete else { return }
        didSignalComplete = true
        onComplete?()
    }

    private func commonPrefixLength(_ left: String, _ right: String) -> Int {
        var count = 0
        for (lhs, rhs) in zip(left, right) where lhs == rhs {
            count += 1
        }
        return count
    }
}
