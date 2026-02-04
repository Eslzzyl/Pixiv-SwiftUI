import Foundation

struct CrashReport: Codable {
    let header: ExportHeader
    let data: CrashReportData
}

struct CrashReportData: Codable {
    let crashType: CrashType
    let timestamp: Date
    let appVersion: String
    let buildNumber: String
    let osVersion: String
    let deviceModel: String
    let exception: ExceptionInfo?
    let signal: SignalInfo?
    let stackTrace: String
    let threadInfo: ThreadInfo
    let appState: AppStateInfo
    let logs: String
}

enum CrashType: String, Codable {
    case uncaughtException
    case signal
    case fatalError
    case unknown
}

struct ExceptionInfo: Codable {
    let name: String
    let reason: String
    let callStack: [String]
}

struct SignalInfo: Codable {
    let signal: Int32
    let signalName: String
    let address: UInt64?
}

struct ThreadInfo: Codable {
    let threadNumber: Int
    let threadName: String?
    let isMain: Bool
}

struct AppStateInfo: Codable {
    let isLoggedIn: Bool
    let currentUserId: String?
    let memoryUsage: UInt64
    let cpuUsage: Double
}
