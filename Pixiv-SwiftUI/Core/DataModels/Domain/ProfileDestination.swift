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
    case downloadSettings
    case dataExport
    case about
}
