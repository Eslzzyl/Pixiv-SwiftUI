import Foundation
import os.log

extension Logger {
    static let network = Logger(subsystem: "com.pixiv.app", category: "Network")
    static let download = Logger(subsystem: "com.pixiv.app", category: "Download")
    static let cache = Logger(subsystem: "com.pixiv.app", category: "Cache")
    static let ui = Logger(subsystem: "com.pixiv.app", category: "UI")
    static let database = Logger(subsystem: "com.pixiv.app", category: "Database")
    static let auth = Logger(subsystem: "com.pixiv.app", category: "Auth")
    static let token = Logger(subsystem: "com.pixiv.app", category: "Token")
    static let ugoira = Logger(subsystem: "com.pixiv.app", category: "Ugoira")
    static let novel = Logger(subsystem: "com.pixiv.app", category: "Novel")
    static let bookmark = Logger(subsystem: "com.pixiv.app", category: "Bookmark")
}