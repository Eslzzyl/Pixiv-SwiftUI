import SwiftUI

struct DownloadTasksView: View {
    @StateObject private var downloadStore = DownloadStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearAlert = false
    @State private var showingClearCompletedAlert = false
    
    var body: some View {
        Group {
            if downloadStore.tasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
        .navigationTitle("下载任务")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if !downloadStore.completedTasks.isEmpty {
                        Button(role: .destructive, action: { showingClearCompletedAlert = true }) {
                            Label("清除已完成", systemImage: "trash")
                        }
                    }
                    
                    Button(role: .destructive, action: { showingClearAlert = true }) {
                        Label("清除全部", systemImage: "trash.fill")
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(downloadStore.tasks.isEmpty)
            }
        }
        .alert("清除全部任务", isPresented: $showingClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                Task { await downloadStore.clearAll() }
            }
        } message: {
            Text("这将删除所有下载任务和已保存的文件。")
        }
        .alert("清除已完成", isPresented: $showingClearCompletedAlert) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                Task { await downloadStore.clearCompleted() }
            }
        } message: {
            Text("这将删除所有已完成的任务和已保存的文件。")
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无下载任务")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text("在插画详情页点击保存即可添加任务")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var taskList: some View {
        List {
            if !downloadStore.downloadingTasks.isEmpty {
                Section("正在下载") {
                    ForEach(downloadStore.downloadingTasks) { task in
                        DownloadTaskRow(downloadStore: downloadStore, task: task)
                    }
                }
            }
            
            if !downloadStore.waitingTasks.isEmpty {
                Section("等待中") {
                    ForEach(downloadStore.waitingTasks) { task in
                        DownloadTaskRow(downloadStore: downloadStore, task: task)
                    }
                }
            }
            
            if !downloadStore.completedTasks.isEmpty {
                Section("已完成") {
                    ForEach(downloadStore.completedTasks) { task in
                        DownloadTaskRow(downloadStore: downloadStore, task: task)
                    }
                }
            }
            
            if !downloadStore.failedTasks.isEmpty {
                Section("失败") {
                    ForEach(downloadStore.failedTasks) { task in
                        DownloadTaskRow(downloadStore: downloadStore, task: task)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DownloadTasksView()
    }
}
