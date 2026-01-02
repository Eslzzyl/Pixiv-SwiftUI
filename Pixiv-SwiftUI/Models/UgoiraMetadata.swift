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
    
    enum CodingKeys: String, CodingKey {
        case medium
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
