import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

enum ExportItemType: String, CaseIterable, Identifiable {
    case searchHistory = "search_history"
    case glanceHistory = "glance_history"
    case muteData = "mute_data"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .searchHistory:
            return "搜索历史"
        case .glanceHistory:
            return "浏览历史"
        case .muteData:
            return "屏蔽数据"
        }
    }

    var icon: String {
        switch self {
        case .searchHistory:
            return "magnifyingglass"
        case .glanceHistory:
            return "clock.arrow.circlepath"
        case .muteData:
            return "nosign"
        }
    }
}

@MainActor
final class DataExportViewModel: ObservableObject {
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var showConflictDialog = false
    @Published var conflictItemType: ExportItemType?
    @Published var pendingImportURL: URL?
    @Published var showShareSheet = false
    @Published var shareURL: URL?
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var showError = false
    @Published var errorMessage = ""

    let exportService = DataExportService.shared

    func export(_ itemType: ExportItemType) async {
        isExporting = true
        defer { isExporting = false }

        do {
            let url: URL
            switch itemType {
            case .searchHistory:
                url = try await exportService.exportSearchHistory()
            case .glanceHistory:
                url = try await exportService.exportGlanceHistory()
            case .muteData:
                url = try await exportService.exportMuteData()
            }

            shareURL = url
            showShareSheet = true
        } catch let error as DataExportError {
            showError = true
            errorMessage = error.localizedDescription
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }

    func prepareImport(itemType: ExportItemType, url: URL) {
        conflictItemType = itemType
        pendingImportURL = url
        showConflictDialog = true
    }

    func handleImport(strategy: ImportConflictStrategy) async {
        guard let url = pendingImportURL,
              let itemType = conflictItemType else { return }

        isImporting = true
        defer {
            isImporting = false
            showConflictDialog = false
            pendingImportURL = nil
            conflictItemType = nil
        }

        do {
            switch itemType {
            case .searchHistory:
                try await exportService.importSearchHistory(from: url, strategy: strategy)
            case .glanceHistory:
                try await exportService.importGlanceHistory(from: url, strategy: strategy)
            case .muteData:
                try await exportService.importMuteData(from: url, strategy: strategy)
            }

            toastMessage = "导入成功"
            showToast = true
        } catch let error as DataExportError {
            if case .cancelled = error {
                return
            }
            showError = true
            errorMessage = error.localizedDescription
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() {
        showError = false
        errorMessage = ""
    }
}
