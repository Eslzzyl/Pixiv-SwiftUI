import Foundation

struct UgoiraMetadataResponse: Codable {
    let ugoiraMetadata: UgoiraMetadata
    
    enum CodingKeys: String, CodingKey {
        case ugoiraMetadata = "ugoira_metadata"
    }
}

struct UgoiraMetadata: Codable {
    let zipUrls: ZipUrls
    let frames: [Frame]
    
    enum CodingKeys: String, CodingKey {
        case zipUrls = "zip_urls"
        case frames
    }
}

struct ZipUrls: Codable {
    let medium: String
    let large: String?
    let original: String?

    enum CodingKeys: String, CodingKey {
        case medium
        case large
        case original
    }

    func url(for quality: Int) -> String {
        switch quality {
        case 0:
            return medium
        case 1:
            return large ?? medium
        default:
            return original ?? large ?? medium
        }
    }
}

struct Frame: Codable {
    let file: String
    let delay: Int
    
    enum CodingKeys: String, CodingKey {
        case file
        case delay
    }
}

extension Frame {
    var delayTimeInterval: TimeInterval {
        TimeInterval(delay) / 1000.0
    }
}
