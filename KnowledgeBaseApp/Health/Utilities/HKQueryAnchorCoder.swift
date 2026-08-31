import Foundation
import HealthKit

enum HKQueryAnchorCoderError: Error, Equatable {
    case decodeFailed
}

enum HKQueryAnchorCoder {
    static func encode(_ anchor: HKQueryAnchor) throws -> Data {
        try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
    }

    static func decode(_ data: Data) throws -> HKQueryAnchor {
        let object = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        guard let anchor = object else {
            throw HKQueryAnchorCoderError.decodeFailed
        }
        return anchor
    }

    static func encodeBase64(_ anchor: HKQueryAnchor) throws -> String {
        try encode(anchor).base64EncodedString()
    }

    static func decodeBase64(_ string: String) throws -> HKQueryAnchor {
        guard let data = Data(base64Encoded: string) else {
            throw HKQueryAnchorCoderError.decodeFailed
        }
        return try decode(data)
    }
}
