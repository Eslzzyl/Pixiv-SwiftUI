import Foundation
import Kanna

final class SauceNAOAPI {
    private let endpoint: URL = {
        guard let url = URL(string: "https://saucenao.com/search.php") else {
            preconditionFailure("Invalid SauceNAO endpoint")
        }
        return url
    }()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchMatches(imageData: Data, fileName: String = "image.jpg") async throws -> [SauceNaoMatch] {
        let boundary = "Boundary-\(UUID().uuidString)"
        let body = makeMultipartBody(imageData: imageData, fileName: fileName, boundary: boundary)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 60
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw AppError.networkError("搜索频率过快，请稍后再试")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw NetworkError.invalidResponse
        }

        if html.contains("Daily Search Limit Exceeded") {
            throw AppError.networkError("已达到今日搜图上限")
        }

        if html.contains("Search Limit Exceeded") {
            throw AppError.networkError("搜索太快啦，请歇会再试")
        }

        return try parseMatches(from: html)
    }

    private func parseMatches(from html: String) throws -> [SauceNaoMatch] {
        let doc = try HTML(html: html, encoding: .utf8)

        var matches: [SauceNaoMatch] = []
        var seen = Set<Int>()

        let containers = doc.css(".result, .resulttable, .resulttablecontent, .resultcontentcolumn, .resultbody, .resulttitle")
        for container in containers {
            let similarity = parseSimilarity(in: container)
            let links = container.css("a[href]")

            for link in links {
                let href = link["href"] ?? ""
                guard let id = extractPixivIllustId(from: href), !seen.contains(id) else {
                    continue
                }
                seen.insert(id)
                matches.append(SauceNaoMatch(illustId: id, similarity: similarity))
                break
            }
        }

        if !matches.isEmpty {
            return matches
        }

        let links = doc.css("a[href]")
        for link in links {
            let href = link["href"] ?? ""
            guard let id = extractPixivIllustId(from: href), !seen.contains(id) else {
                continue
            }
            seen.insert(id)
            matches.append(SauceNaoMatch(illustId: id, similarity: nil))
        }

        return matches
    }

    private func parseSimilarity(in container: Kanna.XMLElement) -> Double? {
        if let similarityElement = container.at_css(".resultsimilarityinfo"),
           let text = similarityElement.text,
           let value = parsePercent(from: text) {
            return value
        }

        if let text = container.text {
            return parsePercent(from: text)
        }

        return nil
    }

    private func parsePercent(from text: String) -> Double? {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*%"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Double(text[valueRange])
    }

    private func extractPixivIllustId(from urlString: String) -> Int? {
        guard let url = URL(string: urlString),
              let host = url.host,
              host.contains("pixiv.net") else {
            return nil
        }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryId = components.queryItems?.first(where: { $0.name == "illust_id" })?.value,
           let illustId = Int(queryId) {
            return illustId
        }

        let parts = url.path.split(separator: "/")
        if let artworksIndex = parts.firstIndex(of: "artworks"),
           artworksIndex + 1 < parts.count,
           let illustId = Int(parts[artworksIndex + 1]) {
            return illustId
        }

        return nil
    }

    private func makeMultipartBody(imageData: Data, fileName: String, boundary: String) -> Data {
        var body = Data()

        // Add form parameters
        let params = [
            "db": "999",
            "numres": "16",
            "hide": "0",
            "frame": "1"
        ]

        for (key, value) in params {
            body.appendUTF8("--\(boundary)\r\n")
            body.appendUTF8("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendUTF8("\(value)\r\n")
        }

        // Add file
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        body.appendUTF8("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.appendUTF8("\r\n")
        body.appendUTF8("--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        append(data)
    }
}
