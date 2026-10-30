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
            lowers.randomElement()!,
            uppers.randomElement()!,
            digits.randomElement()!,
            symbols.randomElement()!
        ]
        let pool = lowers + uppers + digits + symbols
        while chars.count < len {
            chars.append(pool.randomElement()!)
        }
        chars.shuffle()
        return String(chars)
    }
}
