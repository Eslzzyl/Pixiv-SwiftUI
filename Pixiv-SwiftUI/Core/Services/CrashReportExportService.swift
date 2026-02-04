import Foundation
import os.log

final class CrashReportExportService {
    static let shared = CrashReportExportService()

    private let subsystem = "com.pixiv.app"

    private init() {}

    func collectLogs(for crashDate: Date, duration: TimeInterval = 60) throws -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withFractionalSeconds]

        let startDate = crashDate.addingTimeInterval(-duration)
        let endDate = crashDate

        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = [
            "show",
            "--predicate", "subsystem == '\(subsystem)'",
            "--start", startStr,
            "--end", endStr,
            "--style", "compact"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    func hasCrashReports() -> Bool {
        let crashDir = crashReportsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(at: crashDir, includingPropertiesForKeys: nil) else {
            return false
        }
        return !files.isEmpty
    }

    private func crashReportsDirectory() -> URL {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let crashDir = supportDir.appendingPathComponent("CrashReports", isDirectory: true)
        try? FileManager.default.createDirectory(at: crashDir, withIntermediateDirectories: true)
        return crashDir
    }

    func exportCrashReportWithLogs(crashDate: Date) async throws -> URL {
        let logs = try collectLogs(for: crashDate)

        let threadInfo = await MainActor.run {
            ThreadInfo(
                threadNumber: Thread.current.hashValue,
                threadName: Thread.current.name,
                isMain: Thread.isMainThread
            )
        }

        let accountStore = AccountStore.shared

        let report = CrashReport(
            header: ExportHeader(version: 1, type: .crashReport, exportedAt: Date()),
            data: CrashReportData(
                crashType: .unknown,
                timestamp: crashDate,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
                buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                deviceModel: getDeviceModel(),
                exception: nil,
                signal: nil,
                stackTrace: "",
                threadInfo: threadInfo,
                appState: AppStateInfo(
                    isLoggedIn: accountStore.isLoggedIn,
                    currentUserId: accountStore.currentUserId,
                    memoryUsage: getMemoryUsage(),
                    cpuUsage: getCpuUsage()
                ),
                logs: logs
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(report)

        let fileName = "crash_report_\(crashDate.ISO8601Format()).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try jsonData.write(to: tempURL)

        return tempURL
    }

    private func getDeviceModel() -> String {
        #if os(macOS)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelData = Data(bytes: model, count: size)
        let trimmedData = modelData.prefix { $0 != 0 }
        return String(bytes: trimmedData, encoding: .utf8) ?? ""
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
        #endif
    }

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        return 0
    }

    private func getCpuUsage() -> Double {
        var info = task_thread_times_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_thread_times_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_THREAD_TIMES_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.user_time.seconds) + Double(info.system_time.seconds)
        }
        return 0.0
    }
}
