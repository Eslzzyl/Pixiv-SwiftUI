import Foundation

struct SpotlightArticle: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let pureTitle: String
    let thumbnail: String
    let articleUrl: String
    let publishDate: Date
    let tags: [String]
    let category: String

    var displayTitle: String {
        if pureTitle.hasSuffix(" -") {
            return String(pureTitle.dropLast(2))
        }
        return pureTitle
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case pureTitle = "pure_title"
        case thumbnail
        case articleUrl = "article_url"
        case publishDate = "publish_date"
        case tags
        case category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        pureTitle = try container.decode(String.self, forKey: .pureTitle)
        thumbnail = try container.decode(String.self, forKey: .thumbnail)
        articleUrl = try container.decode(String.self, forKey: .articleUrl)
        publishDate = try container.decode(Date.self, forKey: .publishDate)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(pureTitle, forKey: .pureTitle)
        try container.encode(thumbnail, forKey: .thumbnail)
        try container.encode(articleUrl, forKey: .articleUrl)
        try container.encode(publishDate, forKey: .publishDate)
        try container.encode(tags, forKey: .tags)
        try container.encode(category, forKey: .category)
    }

    init(
        id: Int,
        title: String,
        pureTitle: String,
        thumbnail: String,
        articleUrl: String,
        publishDate: Date,
        tags: [String] = [],
        category: String = ""
    ) {
        self.id = id
        self.title = title
        self.pureTitle = pureTitle
        self.thumbnail = thumbnail
        self.articleUrl = articleUrl
        self.publishDate = publishDate
        self.tags = tags
        self.category = category
    }
}

struct SpotlightResponse: Codable {
    let spotlightArticles: [SpotlightArticle]
    let nextUrl: String?

    enum CodingKeys: String, CodingKey {
        case spotlightArticles = "spotlight_articles"
        case nextUrl = "next_url"
    }
}

struct SpotlightWork: Identifiable, Hashable {
    let id: Int
    let title: String
    let user: String
    let userImage: String
    let userLink: String
    let showImage: String
    let artworkLink: String

    init?(title: String?, user: String?, userImage: String?, userLink: String?, showImage: String?, artworkLink: String?) {
        guard let title = title, !title.isEmpty,
              let user = user, !user.isEmpty,
              let userImage = userImage, !userImage.isEmpty,
              let userLink = userLink, !userLink.isEmpty,
              let showImage = showImage, !showImage.isEmpty,
              let artworkLink = artworkLink, !artworkLink.isEmpty else {
            return nil
        }

        self.title = title
        if user.lowercased().hasPrefix("by ") {
            self.user = String(user.dropFirst(3))
        } else if user.lowercased().hasPrefix("by") {
            self.user = String(user.dropFirst(2))
        } else {
            self.user = user
        }
        self.userImage = userImage
        self.userLink = userLink
        self.showImage = showImage
        self.artworkLink = artworkLink

        if let url = URL(string: artworkLink) {
            self.id = Int(url.pathComponents.last ?? "0") ?? 0
        } else {
            self.id = 0
        }
    }
}

struct SpotlightArticleDetail {
    let description: String
    let works: [SpotlightWork]
    let referencedArticleSections: [SpotlightArticleSection]
    let rankingArticles: [SpotlightRelatedArticle]
    let recommendedArticles: [SpotlightRelatedArticle]
}

struct SpotlightArticleSection: Identifiable {
    let id = UUID()
    let heading: String
    let articles: [SpotlightArticle]
}

struct SpotlightRelatedArticle: Identifiable, Hashable {
    let id: Int
    let title: String
    let thumbnail: String
    let articleUrl: String
    let publishDate: Date?
    let category: String

    init(
        id: Int,
        title: String,
        thumbnail: String,
        articleUrl: String,
        publishDate: Date? = nil,
        category: String
    ) {
        self.id = id
        self.title = title
        self.thumbnail = thumbnail
        self.articleUrl = articleUrl
        self.publishDate = publishDate
        self.category = category
    }
}
