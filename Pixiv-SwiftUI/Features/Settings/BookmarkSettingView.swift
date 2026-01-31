import SwiftUI

/// 收藏设置视图
struct BookmarkSettingView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    @State private var bookmarkCacheStore = BookmarkCacheStore.shared
    @State private var accountStore = AccountStore.shared
    @State private var showClearCacheConfirmation = false
    @State private var showClearAllConfirmation = false

    private var userSetting: UserSetting {
        userSettingStore.userSetting
    }

    private var cacheSizeText: String {
        let bytes = bookmarkCacheStore.cacheSizeBytes
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
        } else {
            return String(format: "%.2f GB", Double(bytes) / 1024 / 1024 / 1024)
        }
    }

    private var syncStateText: String {
        switch bookmarkCacheStore.syncState {
        case .idle:
            return ""
        case .fetching(let current, _):
            return String(localized: "正在获取收藏列表... \(current) 个")
        case .detecting:
            return String(localized: "正在检测已删除作品...")
        case .preloading(let current, let total):
            return String(localized: "正在预取图片... \(current)/\(total)")
        case .completed:
            return String(localized: "同步完成")
        case .failed(let error):
            return String(localized: "同步失败: \(error)")
        }
    }

    private var syncProgress: Double {
        switch bookmarkCacheStore.syncState {
        case .preloading(let current, let total):
            return Double(current) / Double(max(total, 1))
        default:
            return 0
        }
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { userSetting.bookmarkCacheEnabled },
                    set: { try? userSettingStore.setBookmarkCacheEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("启用收藏缓存")
                        Text("缓存收藏作品的元数据，检测已删除作品")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("收藏缓存")
            }

            if userSetting.bookmarkCacheEnabled {
                Section {
                    Toggle(isOn: Binding(
                        get: { userSetting.bookmarkAutoPreload },
                        set: { try? userSettingStore.setBookmarkAutoPreload($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("自动预取图片")
                            Text("同步时自动下载收藏作品的图片")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if userSetting.bookmarkAutoPreload {
                        Picker(selection: Binding(
                            get: { userSetting.bookmarkCacheQuality },
                            set: { try? userSettingStore.setBookmarkCacheQuality($0) }
                        )) {
                            Text("中等").tag(0)
                            Text("大图").tag(1)
                            Text("原图").tag(2)
                        } label: {
                            Text("缓存画质")
                        }

                        Toggle(isOn: Binding(
                            get: { userSetting.bookmarkCacheAllPages },
                            set: { try? userSettingStore.setBookmarkCacheAllPages($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("缓存所有页面")
                                Text("对于多页插画，缓存全部页面而非仅封面")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Toggle(isOn: Binding(
                            get: { userSetting.bookmarkCacheUgoira },
                            set: { try? userSettingStore.setBookmarkCacheUgoira($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("缓存动图")
                                Text("缓存 Ugoira 动图的所有帧")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("图片预取")
                }

                Section {
                    HStack {
                        Text("缓存记录")
                        Spacer()
                        Text("\(bookmarkCacheStore.cachedBookmarks.count) 个作品")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("已删除作品")
                        Spacer()
                        Text("\(bookmarkCacheStore.deletedCount) 个")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("图片缓存大小")
                        Spacer()
                        Text(cacheSizeText)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("存储信息")
                }

                Section {
                    #if os(macOS)
                    LabeledContent("执行全量同步") {
                        Button {
                            Task {
                                await bookmarkCacheStore.performFullSync(
                                    userId: accountStore.currentUserId,
                                    ownerId: accountStore.currentUserId,
                                    settings: userSetting
                                )
                            }
                        } label: {
                            HStack {
                                if bookmarkCacheStore.syncState.isRunning {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("同步")
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(bookmarkCacheStore.syncState.isRunning || !accountStore.isLoggedIn)
                    }
                    #else
                    Button {
                        Task {
                            await bookmarkCacheStore.performFullSync(
                                userId: accountStore.currentUserId,
                                ownerId: accountStore.currentUserId,
                                settings: userSetting
                            )
                        }
                    } label: {
                        HStack {
                            Text("执行全量同步")
                            Spacer()
                            if bookmarkCacheStore.syncState.isRunning {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(bookmarkCacheStore.syncState.isRunning || !accountStore.isLoggedIn)
                    #endif

                    if bookmarkCacheStore.syncState != .idle {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(syncStateText)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if case .preloading = bookmarkCacheStore.syncState {
                                ProgressView(value: syncProgress)
                            }
                        }
                    }

                    #if os(macOS)
                    LabeledContent("清理图片缓存") {
                        Button {
                            showClearCacheConfirmation = true
                        } label: {
                            Text("清理")
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .disabled(bookmarkCacheStore.syncState.isRunning)
                    }

                    LabeledContent("清理所有缓存数据") {
                        Button {
                            showClearAllConfirmation = true
                        } label: {
                            Text("清理")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(bookmarkCacheStore.syncState.isRunning)
                    }
                    #else
                    Button(role: .destructive) {
                        showClearCacheConfirmation = true
                    } label: {
                        Text("清理图片缓存")
                    }
                    .disabled(bookmarkCacheStore.syncState.isRunning)

                    Button(role: .destructive) {
                        showClearAllConfirmation = true
                    } label: {
                        Text("清理所有缓存数据")
                    }
                    .disabled(bookmarkCacheStore.syncState.isRunning)
                    #endif
                } header: {
                    Text("同步与管理")
                } footer: {
                    Text("全量同步将获取所有收藏作品，检测已删除作品，并根据设置预取图片。")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("收藏")
        .onAppear {
            if accountStore.isLoggedIn {
                bookmarkCacheStore.loadCachedBookmarks(for: accountStore.currentUserId)
                Task {
                    await bookmarkCacheStore.calculateCacheSize()
                }
            }
        }
        .confirmationDialog("清理图片缓存", isPresented: $showClearCacheConfirmation, titleVisibility: .visible) {
            Button("清理", role: .destructive) {
                Task {
                    await bookmarkCacheStore.clearImageCache()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除所有已缓存的收藏图片，不影响收藏记录数据。")
        }
        .confirmationDialog("清理所有缓存数据", isPresented: $showClearAllConfirmation, titleVisibility: .visible) {
            Button("清理", role: .destructive) {
                bookmarkCacheStore.clearAllCache(ownerId: accountStore.currentUserId)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除所有收藏缓存数据，包括元数据和图片。已删除作品的记录也将被清除。")
        }
    }
}

#Preview {
    BookmarkSettingView()
        .environment(UserSettingStore.shared)
}
