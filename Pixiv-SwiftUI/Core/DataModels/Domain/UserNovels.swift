import Foundation

struct UserNovels: Codable {
    let novels: [Novel]
    let nextUrl: String?

    enum CodingKeys: String, CodingKey {
        case novels
        case nextUrl = "next_url"
    }
}
