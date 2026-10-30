import Foundation

/// Strong passwords for account registration (meets API min length of 8).
enum PasswordGenerator {
    private static let lowers = Array("abcdefghijkmnopqrstuvwxyz")
    private static let uppers = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")
    private static let digits = Array("23456789")
    private static let symbols = Array("!@#$%^&*-_=+")

    static func make(length: Int = 20) -> String {
        let len = max(12, length)
        var chars: [Character] = [
            randomChar(from: lowers),
            randomChar(from: uppers),
            randomChar(from: digits),
            randomChar(from: symbols)
        ]
        let pool = lowers + uppers + digits + symbols
        while chars.count < len {
            chars.append(randomChar(from: pool))
        }
        chars.shuffle()
        return String(chars)
    }

    private static func randomChar(from alphabet: [Character]) -> Character {
        precondition(!alphabet.isEmpty, "Password alphabet must be non-empty")
        return alphabet[Int.random(in: 0..<alphabet.count)]
    }
}
