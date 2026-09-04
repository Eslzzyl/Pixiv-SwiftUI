import Foundation

enum ProfileDestination: Hashable {
    case userDetail(String)
    case browseHistory
    case settings
    case appearance
    case privacy
    case downloadTasks
    case blockSettings
    case translationSettings
    case syncSettings
    case downloadSettings
    case networkSettings
    case dataExport
    case about
}
