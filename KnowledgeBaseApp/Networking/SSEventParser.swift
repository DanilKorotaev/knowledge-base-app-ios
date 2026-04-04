import Foundation

/// Parses [Server-Sent Events](https://html.spec.whatwg.org/multipage/server-sent-events.html) `data:` fields for chat streaming.
enum SSEventParser {
    /// Returns concatenated `data` lines for each event block (events separated by blank lines).
    static func dataPayloads(fromCompleteBody sseBody: String) -> [String] {
        let normalized = sseBody.replacingOccurrences(of: "\r\n", with: "\n")
        let blocks = normalized.split(separator: "\n\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return blocks.compactMap { extractDataBlock(from: $0) }
    }

    /// Incremental buffer: append UTF-8 chunks from `URLSession.bytes` and receive full `data` payloads when `\n\n` closes an event.
    struct StreamBuffer {
        private var buffer: String = ""

        mutating func append(_ chunk: String) -> [String] {
            let piece = chunk.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            buffer += piece
            var payloads: [String] = []
            while true {
                guard let range = buffer.range(of: "\n\n") else { break }
                let block = String(buffer[..<range.lowerBound])
                buffer.removeSubrange(..<range.upperBound)
                if let data = SSEventParser.extractDataBlock(from: block) {
                    payloads.append(data)
                }
            }
            return payloads
        }

        mutating func reset() {
            buffer = ""
        }
    }

    private static func extractDataBlock(from block: String) -> String? {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var dataLines: [String] = []
        for line in lines {
            if line.hasPrefix(":") {
                continue
            }
            guard line.hasPrefix("data:") else { continue }
            var rest = line.dropFirst(5)
            if rest.first == " " {
                rest = rest.dropFirst()
            }
            dataLines.append(String(rest))
        }
        guard !dataLines.isEmpty else { return nil }
        return dataLines.joined(separator: "\n")
    }

    /// One SSE event block (lines between blank lines), without the trailing blank line.
    static func dataPayload(fromSingleEventBlock block: String) -> String? {
        extractDataBlock(from: block)
    }
}
