import Foundation

/// JSON-safe serialization of APNs `userInfo` for debug logs.
enum PushPayloadFormatter {
    static func json(_ userInfo: [AnyHashable: Any]) -> String {
        let normalized = normalizeDictionary(userInfo)
        guard JSONSerialization.isValidJSONObject(normalized),
              let data = try? JSONSerialization.data(withJSONObject: normalized, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return String(describing: normalized)
        }
        return text
    }

    private static func normalizeDictionary(_ dictionary: [AnyHashable: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in dictionary {
            result[String(describing: key)] = normalize(value)
        }
        return result
    }

    private static func normalize(_ value: Any) -> Any {
        switch value {
        case let nested as [AnyHashable: Any]:
            return normalizeDictionary(nested)
        case let array as [Any]:
            return array.map { normalize($0) }
        case let string as String:
            return string
        case let number as NSNumber:
            return number
        case let data as Data:
            return data.base64EncodedString()
        case let date as Date:
            return ISO8601DateFormatter().string(from: date)
        case let url as URL:
            return url.absoluteString
        default:
            return String(describing: value)
        }
    }
}
