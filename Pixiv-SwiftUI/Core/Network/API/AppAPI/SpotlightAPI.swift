import Foundation
import Kanna

final class SpotlightAPI {
    private let client = NetworkClient.shared
    private let baseUrl = "https://www.pixivision.net"

    struct ArticleListResult {
        let articles: [SpotlightArticle]
        let currentPage: Int
        let hasNextPage: Bool
    }

    func getSpotlightArticles(category: String = "all") async throws -> (articles: [SpotlightArticle], nextUrl: String?) {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/spotlight/articles")
        components?.queryItems = [
            URLQueryItem(name: "filter", value: "for_android"),
            URLQueryItem(name: "category", value: category)
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: [:],
            responseType: SpotlightResponse.self
        )

        return (response.spotlightArticles, response.nextUrl)
    }

    func getSpotlightArticlesByURL(_ urlString: String) async throws -> (articles: [SpotlightArticle], nextUrl: String?) {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: [:],
            responseType: SpotlightResponse.self
        )

        return (response.spotlightArticles, response.nextUrl)
    }

    func getCategoryArticles(category: SpotlightCategory, page: Int = 1) async throws -> ArticleListResult {
        let urlString: String
        if page == 1 {
            urlString = "\(baseUrl)\(category.urlPath)"
        } else {
            urlString = "\(baseUrl)\(category.urlPath)/?p=\(page)"
        }
        let html = try await fetchHTML(url: urlString)
        return try parseArticleListHTML(html, page: page)
    }

    func searchArticles(query: String, page: Int = 1) async throws -> ArticleListResult {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw NetworkError.invalidResponse
        }
        let urlString: String
        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        let langPath = (langCode == "zh" || langCode.hasPrefix("zh-")) ? "zh" : "en"
        if page == 1 {
            urlString = "\(baseUrl)/\(langPath)/s/?q=\(encodedQuery)"
        } else {
            urlString = "\(baseUrl)/\(langPath)/s/?q=\(encodedQuery)&p=\(page)"
        }
        let html = try await fetchHTML(url: urlString)
        return try parseArticleListHTML(html, page: page)
    }

    private func parseArticleListHTML(_ html: String, page: Int) throws -> ArticleListResult {
        let doc = try HTML(html: html, encoding: .utf8)
        var articles: [SpotlightArticle] = []

        let articleCards = doc.css("ul.main-column-container > li.article-card-container")

        for card in articleCards {
            if let article = parseArticleCard(card) {
                articles.append(article)
            }
        }

        let hasNextPage = checkHasNextPage(doc: doc)

        return ArticleListResult(
            articles: articles,
            currentPage: page,
            hasNextPage: hasNextPage
        )
    }

    private func parseArticleCard(_ card: Kanna.XMLElement) -> SpotlightArticle? {
        guard let titleLink = card.at_css(".arc__title a"),
              let href = titleLink["href"]?.nilIfEmpty,
              let title = titleLink.text?.nilIfEmpty else {
            return nil
        }

        let articleId: Int
        if let lastComponent = href.split(separator: "/").last,
           let id = Int(lastComponent) {
            articleId = id
        } else {
            return nil
        }

        let thumbnail: String
        if let thumbDiv = card.at_css("._thumbnail"),
           let style = thumbDiv["style"]?.nilIfEmpty {
            thumbnail = extractBackgroundImageUrl(from: style) ?? ""
        } else {
            thumbnail = ""
        }

        if thumbnail.isEmpty {
            return nil
        }

        let articleUrl = href.hasPrefix("http") ? href : baseUrl + href

        let category: String
        if let categoryLabel = card.at_css(".arc__thumbnail-label") {
            category = categoryLabel.text ?? ""
        } else {
            category = ""
        }

        let tags = card.css(".tls__list-item").compactMap { $0.text?.nilIfEmpty }

        let publishDate: Date
        if let timeElement = card.at_css("time._date"),
           let datetime = timeElement["datetime"]?.nilIfEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            publishDate = formatter.date(from: datetime) ?? Date()
        } else {
            publishDate = Date()
        }

        let pureTitle = title
            .replacingOccurrences(of: "^#\\S+\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        return SpotlightArticle(
            id: articleId,
            title: title,
            pureTitle: pureTitle.isEmpty ? title : pureTitle,
            thumbnail: thumbnail,
            articleUrl: articleUrl,
            publishDate: publishDate,
            tags: tags,
            category: category
        )
    }

    private func extractBackgroundImageUrl(from style: String) -> String? {
        let pattern = #"background-image:\s*url\(['"]?([^'")\s]+)['"]?\)"#
        guard let range = style.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        let urlMatch = style[range]
        guard let startIndex = urlMatch.firstIndex(of: "("),
              let endIndex = urlMatch.lastIndex(of: ")") else {
            return nil
        }
        let urlStart = urlMatch.index(after: startIndex)
        return String(urlMatch[urlStart..<endIndex])
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }

    private func checkHasNextPage(doc: Kanna.HTMLDocument) -> Bool {
        if let nextLink = doc.at_css("._pager a.next") {
            let href = nextLink["href"] ?? ""
            return !href.isEmpty
        }
        return false
    }

    func fetchArticleDetail(url: String, languageCode: Int = 0) async throws -> SpotlightArticleDetail {
        let html = try await fetchHTML(url: url)
        return try parseArticleHTML(html, languageCode: languageCode)
    }

    private func fetchHTML(url: String) async throws -> String {
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidResponse
        }

        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        let isChinese = (langCode == "zh" || langCode.hasPrefix("zh-"))
        let acceptLanguage = isChinese ? "zh-CN,zh;q=0.9,en;q=0.8" : "en-US,en;q=0.9"
        let referer = isChinese ? "https://www.pixivision.net/zh/" : "https://www.pixivision.net/en/"

        let headers: [String: String] = [
            "Accept-Language": acceptLanguage,
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.26 Safari/537.36",
            "Referer": referer
        ]

        return try await client.getRaw(url: requestURL, headers: headers)
    }

    private func parseArticleHTML(_ html: String, languageCode: Int) throws -> SpotlightArticleDetail {
        let doc = try HTML(html: html, encoding: .utf8)

        guard let article = doc.at_css("article"),
              let amBody = article.at_css(".am__body") else {
            return SpotlightArticleDetail(description: "", works: [], referencedArticleSections: [], rankingArticles: [], recommendedArticles: [])
        }

        var nodes = amBody.children
        var description = ""

        if let firstClass = nodes.first?["class"], firstClass.contains("_feature") {
            if let featureContainer = nodes.first {
                description = extractFeatureDescription(from: featureContainer)
            }
            nodes = nodes.first?.children ?? nodes
        } else {
            if let header = article.at_css(".am__header") {
                description = extractDescription(from: header)
            }
        }

        if description.isEmpty {
            description = extractFallbackDescription(doc: doc, amBody: amBody)
        }

        var works: [SpotlightWork] = []
        let referencedArticleSections = extractReferencedArticleSections(from: nodes)

        for node in nodes {
            guard let nodeClass = node["class"]?.nilIfEmpty,
                  nodeClass.contains("illust") else {
                continue
            }

            var artworkLink: String?
            var showImage: String?
            var title: String?
            var userLink: String?
            var user: String?
            var userImage: String?

            let links = node.css("a")
            for link in links {
                guard let href = link["href"]?.nilIfEmpty else { continue }

                if href.contains("/artworks/") {
                    artworkLink = href
                    let imgs = node.css("img")
                    if imgs.count > 1 {
                        showImage = imgs[1]["src"]
                    }
                    if let titleElement = node.at_css("h3") {
                        title = titleElement.text
                    }
                } else if href.contains("/users/") {
                    userLink = href
                    if let userElement = node.at_css("p") {
                        user = userElement.text
                    }
                    let imgs = node.css("img")
                    if imgs.first != nil {
                        userImage = imgs[0]["src"]
                    }
                }
            }

            if let work = SpotlightWork(
                title: title,
                user: user,
                userImage: userImage,
                userLink: userLink,
                showImage: showImage,
                artworkLink: artworkLink
            ) {
                works.append(work)
            }
        }

        let rankingArticles = extractRelatedArticles(doc: doc, category: "Ranking Area")
        let recommendedArticles = extractRelatedArticles(doc: doc, category: "Osusume Area")

        return SpotlightArticleDetail(
            description: description,
            works: works,
            referencedArticleSections: referencedArticleSections,
            rankingArticles: rankingArticles,
            recommendedArticles: recommendedArticles
        )
    }

    private func extractReferencedArticleSections(from nodes: [Kanna.XMLElement]) -> [SpotlightArticleSection] {
        var sections: [SpotlightArticleSection] = []
        var currentHeading = ""
        var currentArticles: [SpotlightArticle] = []

        for node in nodes {
            guard let nodeClass = node["class"], !nodeClass.isEmpty else { continue }

            if nodeClass.contains("_feature-article-body__heading") {
                if !currentArticles.isEmpty {
                    sections.append(SpotlightArticleSection(
                        heading: currentHeading,
                        articles: currentArticles
                    ))
                    currentArticles = []
                }
                currentHeading = node.text ?? ""
                continue
            }

            if nodeClass.contains("_feature-article-body__article_card") {
                guard let articleCard = node.at_css("article"),
                      let article = parseArticleCard(articleCard) else { continue }
                currentArticles.append(article)
            }
        }

        if !currentArticles.isEmpty {
            sections.append(SpotlightArticleSection(
                heading: currentHeading,
                articles: currentArticles
            ))
        }

        return sections
    }

    private func extractRelatedArticles(doc: Kanna.HTMLDocument, category: String) -> [SpotlightRelatedArticle] {
        guard let sidebar = doc.at_css(".sidebar-container") else {
            return []
        }

        guard let section = sidebar.css("[data-gtm-category]").first(where: { $0["data-gtm-category"] == category }) else {
            return []
        }

        var articles: [SpotlightRelatedArticle] = []
        let listItems = section.css(".alc__articles-list-item")

        for item in listItems {
            guard let link = item.at_css(".asc__thumbnail-container a"),
                  let href = link["href"]?.nilIfEmpty else {
                continue
            }

            let thumbnail: String
            if let thumbDiv = item.at_css("._thumbnail"),
               let style = thumbDiv["style"]?.nilIfEmpty {
                let pattern = #"background-image:\s*url\(['"]?([^'")\s]+)['"]?\)"#
                if let range = style.range(of: pattern, options: .regularExpression) {
                    let urlMatch = style[range]
                    let start = urlMatch.firstIndex(of: "(") ?? urlMatch.startIndex
                    let end = urlMatch.lastIndex(of: ")") ?? urlMatch.endIndex
                    let urlString = String(urlMatch[urlMatch.index(after: start)..<end])
                        .replacingOccurrences(of: "'", with: "")
                        .replacingOccurrences(of: "\"", with: "")
                    thumbnail = urlString
                } else {
                    continue
                }
            } else {
                continue
            }

            let title: String
            if let titleElement = item.at_css(".asc__title") {
                title = titleElement.text ?? ""
            } else {
                continue
            }

            let categoryLabel: String
            if let categoryElement = item.at_css("._category-label") {
                categoryLabel = categoryElement.text ?? ""
            } else {
                categoryLabel = ""
            }

            let articleId: Int
            if let lastComponent = href.split(separator: "/").last,
               let id = Int(lastComponent) {
                articleId = id
            } else {
                articleId = 0
            }

            let baseUrl = "https://www.pixivision.net"
            let articleUrl = href.hasPrefix("http") ? href : baseUrl + href

            let relatedArticle = SpotlightRelatedArticle(
                id: articleId,
                title: title,
                thumbnail: thumbnail,
                articleUrl: articleUrl,
                category: categoryLabel
            )
            articles.append(relatedArticle)
        }

        return articles
    }

    private func extractFeatureDescription(from container: Kanna.XMLElement) -> String {
        let paragraphElements = container.css("._feature-article-body__paragraph")
        for element in paragraphElements {
            let text = extractStructuredText(from: element)
            if !text.isEmpty {
                return text
            }
        }
        return ""
    }

    private func extractDescription(from header: Kanna.XMLElement) -> String {
        extractStructuredText(from: header)
    }

    private func extractFallbackDescription(doc: Kanna.HTMLDocument, amBody: Kanna.XMLElement) -> String {
        if let featureContainer = amBody.at_css("._feature-article-body") {
            let featureDescription = extractFeatureDescription(from: featureContainer)
            if !featureDescription.isEmpty {
                return featureDescription
            }
        }

        if let firstParagraph = amBody.at_css("._feature-article-body__paragraph") {
            let text = extractStructuredText(from: firstParagraph)
            if !text.isEmpty {
                return text
            }
        }

        if let ogDescription = doc.at_css("meta[property=og:description]"),
           let content = ogDescription["content"]?.nilIfEmpty {
            return sanitizeDescriptionLine(content)
        }

        if let metaDescription = doc.at_css("meta[name=description]"),
           let content = metaDescription["content"]?.nilIfEmpty {
            return sanitizeDescriptionLine(content.replacingOccurrences(of: "[pixivision]", with: ""))
        }

        return ""
    }

    private func extractStructuredText(from element: Kanna.XMLElement) -> String {
        let blocks = element.css("div.fab__paragraph._medium-editor-text > div, div.fab__paragraph._medium-editor-text > p, p")
        if blocks.first != nil {
            var lines: [String] = []
            for block in blocks {
                let line = sanitizeDescriptionLine(extractTextPreservingInlineStyles(from: block))
                if !line.isEmpty {
                    lines.append(line)
                }
            }
            if !lines.isEmpty {
                return lines.joined(separator: "\n\n")
            }
        }

        return sanitizeDescriptionLine(extractTextPreservingInlineStyles(from: element))
    }

    private func extractTextPreservingInlineStyles(from element: Kanna.XMLElement) -> String {
        var result = element.innerHTML ?? element.text ?? ""
        let htmlOptions: String.CompareOptions = [.regularExpression, .caseInsensitive]
        result = result.replacingOccurrences(of: #"<\s*br\s*/?\s*>"#, with: "\n", options: htmlOptions)
        result = result.replacingOccurrences(of: #"<\s*(b|strong)\b[^>]*>"#, with: "[[B]]", options: htmlOptions)
        result = result.replacingOccurrences(of: #"<\s*/\s*(b|strong)\s*>"#, with: "[[/B]]", options: htmlOptions)
        result = result.replacingOccurrences(of: #"<\s*(i|em)\b[^>]*>"#, with: "[[I]]", options: htmlOptions)
        result = result.replacingOccurrences(of: #"<\s*/\s*(i|em)\s*>"#, with: "[[/I]]", options: htmlOptions)
        result = TextCleaner.stripHTMLTags(result)
        result = TextCleaner.decodeHTMLEntities(result)
        result = result.replacingOccurrences(of: "[[B]][[/B]]", with: "")
        result = result.replacingOccurrences(of: "[[I]][[/I]]", with: "")
        return result
    }

    private func sanitizeDescriptionLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    var nilIfEmpty: String? {
        return self.isEmpty ? nil : self
    }
}
