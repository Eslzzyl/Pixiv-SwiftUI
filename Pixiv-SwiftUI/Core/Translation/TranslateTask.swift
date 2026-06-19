import Foundation

struct TranslateTask: @unchecked Sendable {
    var raw: String
    var result: String
    var sourceLanguage: String?
    var targetLanguage: String
    var secret: String?
    var status: TaskStatus

    nonisolated init(
        raw: String,
        sourceLanguage: String? = nil,
        targetLanguage: String,
        secret: String? = nil
    ) {
        self.raw = raw
        self.result = ""
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.secret = secret
        self.status = .pending
    }

    mutating func reset() {
        self.result = ""
        self.status = .pending
    }
}

enum TaskStatus: String, @unchecked Sendable {
    case pending
    case processing
    case success
    case failed
}
