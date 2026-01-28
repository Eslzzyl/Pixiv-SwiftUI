import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

struct DataExportView: View {
    @StateObject private var viewModel = DataExportViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(ExportItemType.allCases) { itemType in
                    ExportItemRow(
                        itemType: itemType,
                        isExporting: viewModel.isExporting,
                        onExport: {
                            Task {
                                await viewModel.export(itemType)
                            }
                        },
                        onImport: { url in
                            viewModel.prepareImport(itemType: itemType, url: url)
                        }
                    )
                }

                Divider()

                Text("兼容 PixEz Flutter 导出的数据格式")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .navigationTitle("数据导入/导出")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .overlay {
            if viewModel.showConflictDialog, let itemType = viewModel.conflictItemType {
                ConflictDialog(itemType: itemType) { strategy in
                    Task {
                        await viewModel.handleImport(strategy: strategy)
                    }
                }
                .background(.black.opacity(0.3))
            }
        }
        #if os(iOS)
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let url = viewModel.shareURL {
                ShareSheetView(items: [url])
            }
        }
        #endif
        .onChange(of: viewModel.showShareSheet) { _, isShowing in
            #if os(macOS)
            if isShowing, let url = viewModel.shareURL {
                showSavePanel(for: url)
            }
            #endif
        }
        .onChange(of: viewModel.showToast) { _, show in
            if show {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        viewModel.showToast = false
                    }
                }
            }
        }
    }

    #if os(macOS)
    private func showSavePanel(for url: URL) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = url.lastPathComponent
        savePanel.allowedContentTypes = [.json]
        savePanel.isExtensionHidden = false

        savePanel.begin { response in
            if response == .OK, let saveURL = savePanel.url {
                do {
                    let fileData = try Data(contentsOf: url)
                    try fileData.write(to: saveURL)
                } catch {
                    print("Failed to save file: \(error)")
                }
            }
            viewModel.showShareSheet = false
        }
    }
    #endif
}

struct ShareSheetView: View {
    let items: [Any]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(iOS)
        ShareActivityView(activityItems: items) {
            dismiss()
        }
        #endif
    }
}

#if os(iOS)
import UIKit

struct ShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

struct ExportItemRow: View {
    let itemType: ExportItemType
    let isExporting: Bool
    let onExport: () -> Void
    let onImport: (URL) -> Void

    @State private var showFilePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: itemType.icon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(itemType.displayName)
                        .font(.headline)

                    Text(description(for: itemType))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button(action: onExport) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text("导出")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)

                Button {
                    showFilePicker = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("导入")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(rowBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    onImport(url)
                }
            case .failure:
                break
            }
        }
    }

    private func description(for type: ExportItemType) -> String {
        switch type {
        case .searchHistory:
            return "导出/导入搜索历史记录"
        case .glanceHistory:
            return "导出/导入插画和小说浏览历史"
        case .muteData:
            return "导出/导入屏蔽的标签、用户和作品"
        }
    }

    private var rowBackgroundColor: Color {
        #if os(iOS)
        Color(.secondarySystemBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
}

#Preview {
    NavigationStack {
        DataExportView()
    }
}
