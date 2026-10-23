import Foundation

/// Authenticated open targets for a changed vault file (no public share).
struct KBFileOpenLink: Equatable, Sendable {
    let webURL: URL
    let nextcloudDeepLink: URL?
    let path: String

    init(webURL: URL, nextcloudDeepLink: URL?, path: String) {
        self.webURL = webURL
        self.nextcloudDeepLink = nextcloudDeepLink
        self.path = path
    }
}

extension KBFileOpenLink: Decodable {
    enum CodingKeys: String, CodingKey {
        case webURL = "web_url"
        case nextcloudDeepLink = "nextcloud_deeplink"
        case path
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let webString = try container.decode(String.self, forKey: .webURL)
        guard let webURL = URL(string: webString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .webURL,
                in: container,
                debugDescription: "Invalid web_url"
            )
        }
        self.webURL = webURL
        if let deep = try container.decodeIfPresent(String.self, forKey: .nextcloudDeepLink),
           let deepURL = URL(string: deep) {
            self.nextcloudDeepLink = deepURL
        } else {
            self.nextcloudDeepLink = nil
        }
        self.path = try container.decodeIfPresent(String.self, forKey: .path) ?? ""
    }
}
