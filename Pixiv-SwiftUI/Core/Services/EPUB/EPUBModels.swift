import Foundation

struct EPUBManifest: Codable {
    let id: String
    let title: String
    let author: String
    let language: String
    let modifiedDate: Date
    let coverImage: String?
    let description: String?

    var modifiedDateISO8601: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: modifiedDate)
    }
}

struct EPUBChapter: Codable {
    let id: String
    let title: String?
    let fileName: String
    let content: String
    let order: Int
}

struct EPUBImage: Codable {
    let id: String
    let fileName: String
    let mediaType: String
    let data: Data
}

struct EPUBResource: Codable {
    let id: String
    let href: String
    let mediaType: String
}
