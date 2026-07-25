import Foundation

protocol TranslateService: Sendable {
    static var id: String { get }
    static var name: String? { get }
    static var type: ServiceType { get }
    static var requiresSecret: Bool { get }
    static var defaultSecret: String? { get }
    static var secretValidator: (@Sendable (String?) -> SecretValidationResult)? { get }

    func translate(_ task: inout TranslateTask) async throws
}

enum ServiceType: String, Codable, Sendable {
    case word
    case sentence
}

struct SecretValidationResult: Sendable {
    let secret: String
    let status: Bool
    let info: String
}
