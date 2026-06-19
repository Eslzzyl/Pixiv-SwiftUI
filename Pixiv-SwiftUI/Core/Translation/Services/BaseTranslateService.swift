import Foundation

class BaseTranslateService: @unchecked Sendable {
    let networkClient: TranslationNetworkClient

    nonisolated init(networkClient: TranslationNetworkClient = TranslationNetworkClient()) {
        self.networkClient = networkClient
    }

    func buildTranslateURL(
        baseURL: String,
        text: String,
        sourceLang: String,
        targetLang: String,
        tk: String
    ) throws -> URL {
        var urlComponents = URLComponents(string: baseURL + "/translate_a/single")
        guard urlComponents != nil else {
            throw TranslateError.invalidURL
        }

        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text

        urlComponents?.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: sourceLang),
            URLQueryItem(name: "tl", value: targetLang),
            URLQueryItem(name: "hl", value: "en"),
            URLQueryItem(name: "dt", value: "at"),
            URLQueryItem(name: "dt", value: "bd"),
            URLQueryItem(name: "dt", value: "ex"),
            URLQueryItem(name: "dt", value: "ld"),
            URLQueryItem(name: "dt", value: "md"),
            URLQueryItem(name: "dt", value: "qca"),
            URLQueryItem(name: "dt", value: "rw"),
            URLQueryItem(name: "dt", value: "rm"),
            URLQueryItem(name: "dt", value: "ss"),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "source", value: "bh"),
            URLQueryItem(name: "ssel", value: "0"),
            URLQueryItem(name: "tsel", value: "0"),
            URLQueryItem(name: "kc", value: "1"),
            URLQueryItem(name: "tk", value: tk),
            URLQueryItem(name: "q", value: encodedText)
        ]

        guard let url = urlComponents?.url else {
            throw TranslateError.invalidURL
        }

        return url
    }

    func buildPostBody(
        text: String,
        sourceLang: String,
        targetLang: String
    ) -> [String: Any] {
        return [
            "q": text,
            "client": "at",
            "sl": sourceLang,
            "tl": targetLang,
            "dt": "t",
            "ie": "UTF-8",
            "oe": "UTF-8",
            "dj": "1"
        ]
    }

    func parseResponse(_ data: Data) throws -> String {
        struct Response: Decodable {
            let sentences: [GoogleSentence]?
        }

        struct GoogleSentence: Decodable {
            let trans: String?
            let orig: String?
        }

        let response = try JSONDecoder().decode(Response.self, from: data)

        guard let sentences = response.sentences else {
            throw TranslateError.parsingError
        }

        var result = ""
        for sentence in sentences {
            if let trans = sentence.trans {
                result += trans
            }
        }

        return result
    }
}
