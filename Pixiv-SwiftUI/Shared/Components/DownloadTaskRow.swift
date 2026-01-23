import SwiftUI
import Kingfisher

struct DownloadTaskRow: View {
    @ObservedObject var downloadStore: DownloadStore
    let task: DownloadTask
    @State private var showingActionSheet = false

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .lineLimit(1)

                Text(task.authorName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                statusView
            }

            Spacer()

            actionButtons
        }
        .padding(.vertical, 4)
    }

    private var thumbnailView: some View {
        Group {
            if let urlString = task.imageURLs.first, !urlString.isEmpty {
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(urlString: urlString)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if task.contentType == .ugoira {
                        Image(systemName: "play.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(2)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .padding(4)                    } else if task.pageCount > 1 {
                        Text("\(task.pageCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                            .padding(4)                    }
                }
            } else if task.contentType == .ugoira {
                // 动图显示特殊图标（无预览图时）
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 60, height: 60)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                placeholderImage
            }
        }
    }

    private var placeholderImage: some View {
        Image(systemName: "photo")
            .font(.title2)
            .foregroundColor(.secondary)
            .frame(width: 60, height: 60)
            .background(Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var statusView: some View {
        switch task.status {
        case .downloading:
            HStack(spacing: 8) {
                ProgressView(value: task.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 100)

                Text("\(Int(task.progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

        case .completed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("已完成")
                    .font(.caption)
                    .foregroundColor(.green)
            }

        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
                Text(task.error ?? "失败")
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }

        case .paused:
            HStack(spacing: 4) {
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
                Text("已暂停")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

        case .waiting:
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text("等待中")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button(action: { showingActionSheet = true }) {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
        }
        .buttonStyle(.plain)
        .confirmationDialog("操作", isPresented: $showingActionSheet) {
            switch task.status {
            case .downloading:
                Button("暂停", action: { Task { await downloadStore.pauseTask(id: task.id) } })

            case .paused, .waiting:
                Button("继续", action: { Task { await downloadStore.resumeTask(id: task.id) } })

            case .failed:
                Button("重试", action: { Task { await downloadStore.retryTask(id: task.id) } })

            case .completed:
                #if os(macOS)
                if #available(macOS 13.0, *), let path = task.savedPaths.first {
                    Button("打开位置", action: { NSWorkspace.shared.open(path) })
                }
                #endif
            }

            Divider()

            Button("删除", role: .destructive, action: { Task { await downloadStore.deleteTask(id: task.id) } })

            Button("取消", role: .cancel) {}
        }
    }
}

#Preview {
    List {
        DownloadTaskRow(
            downloadStore: DownloadStore.shared,
            task: DownloadTask(
                illustId: 123,
                title: "测试插画标题",
                authorName: "测试画师",
                pageCount: 3,
                imageURLs: ["https://example.com/image.jpg"],
                quality: 2,
                status: .downloading,
                progress: 0.65,
                currentPage: 2
            )
        )

        DownloadTaskRow(
            downloadStore: DownloadStore.shared,
            task: DownloadTask(
                illustId: 456,
                title: "另一个插画",
                authorName: "另一个画师",
                pageCount: 1,
                imageURLs: ["https://example.com/image2.jpg"],
                quality: 2,
                status: .completed,
                savedPaths: [URL(fileURLWithPath: "/tmp/test.jpg")]
            )
        )
    }
}
