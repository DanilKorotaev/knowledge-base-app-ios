import Foundation

struct KBAttachment: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let fileType: String
    let fileName: String?
    let fileSize: Int?
    let mimeType: String?
    let downloadURL: String?
    let transcription: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fileType = "file_type"
        case fileName = "file_name"
        case fileSize = "file_size"
        case mimeType = "mime_type"
        case downloadURL = "download_url"
        case transcription
    }

    var isImage: Bool {
        fileType == "photo" || mimeType?.hasPrefix("image/") == true
    }

    var isVoice: Bool {
        fileType == "voice" || mimeType?.hasPrefix("audio/") == true
    }
}
