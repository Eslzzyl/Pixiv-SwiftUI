import SwiftUI
import Kingfisher

struct GeneralSettingsView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    @State private var cacheSize: String = "计算中..."
    @State private var showingClearCacheAlert = false
    @State private var isClearingCache = false

    var body: some View {
        Form {
            imageQualitySection
            layoutSection
            #if os(macOS)
            macOSSection
            #endif
            cacheSection
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "通用"))
        .task {
            await loadCacheSize()
        }
        .alert(String(localized: "确认清除缓存"), isPresented: $showingClearCacheAlert) {
            Button(String(localized: "取消"), role: .cancel) { }
            Button(String(localized: "清除"), role: .destructive) {
                Task { await clearCache() }
            }
        } message: {
            Text(String(localized: "您确定要清除所有图片缓存吗？此操作不可撤销。"))
        }
    }

    private var imageQualitySection: some View {
        Section {
            LabeledContent(String(localized: "列表预览画质")) {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.feedPreviewQuality },
                    set: { try? userSettingStore.setFeedPreviewQuality($0) }
                )) {
                    Text(String(localized: "中等")).tag(0)
                    Text(String(localized: "大图")).tag(1)
                    Text(String(localized: "原图")).tag(2)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.segmented)
                .frame(minWidth: 180)
                #endif
            }

            LabeledContent(String(localized: "插画详情页画质")) {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.pictureQuality },
                    set: { try? userSettingStore.setPictureQuality($0) }
                )) {
                    Text(String(localized: "中等")).tag(0)
                    Text(String(localized: "大图")).tag(1)
                    Text(String(localized: "原图")).tag(2)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.segmented)
                .frame(minWidth: 180)
                #endif
            }

            LabeledContent(String(localized: "漫画详情页画质")) {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.mangaQuality },
                    set: { try? userSettingStore.setMangaQuality($0) }
                )) {
                    Text(String(localized: "中等")).tag(0)
                    Text(String(localized: "大图")).tag(1)
                    Text(String(localized: "原图")).tag(2)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.segmented)
                .frame(minWidth: 180)
                #endif
            }

            LabeledContent(String(localized: "大图预览画质")) {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.zoomQuality },
                    set: { try? userSettingStore.setZoomQuality($0) }
                )) {
                    Text(String(localized: "中等")).tag(0)
                    Text(String(localized: "大图")).tag(1)
                    Text(String(localized: "原图")).tag(2)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.segmented)
                .frame(minWidth: 180)
                #endif
            }
        } header: {
            Text(String(localized: "图片质量"))
        } footer: {
            Text(String(localized: "中等画质节省流量，大图画质更清晰，原图画质最高清（可能消耗更多流量）"))
        }
    }

    private var layoutSection: some View {
        Section {
            LabeledContent(String(localized: "竖屏列数")) {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.crossCount },
                    set: { try? userSettingStore.setCrossCount($0) }
                )) {
                    Text(String(localized: "1 列")).tag(1)
                    Text(String(localized: "2 列")).tag(2)
                    Text(String(localized: "3 列")).tag(3)
                    Text(String(localized: "4 列")).tag(4)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }

            LabeledContent(String(localized: "横屏列数")) {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.hCrossCount },
                    set: { try? userSettingStore.setHCrossCount($0) }
                )) {
                    Text(String(localized: "2 列")).tag(2)
                    Text(String(localized: "3 列")).tag(3)
                    Text(String(localized: "4 列")).tag(4)
                    Text(String(localized: "5 列")).tag(5)
                    Text(String(localized: "6 列")).tag(6)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }
        } header: {
            Text(String(localized: "布局"))
        }
    }

    #if os(macOS)
    private var macOSSection: some View {
        Section {
            Toggle("关闭所有窗口后退出程序", isOn: Binding(
                get: { userSettingStore.userSetting.quitAfterWindowClosed },
                set: { try? userSettingStore.setQuitAfterWindowClosed($0) }
            ))
            .toggleStyle(.switch)
        } header: {
            Text("macOS 行为")
        }
    }
    #endif

    private var cacheSection: some View {
        Section {
            HStack {
                Text(String(localized: "图片缓存大小"))
                Spacer()
                Text(cacheSize)
                    .foregroundColor(.secondary)
            }

            #if os(macOS)
            LabeledContent(String(localized: "清除缓存")) {
                Button(role: .destructive) {
                    showingClearCacheAlert = true
                } label: {
                    HStack {
                        if isClearingCache {
                            ProgressView()
                                #if os(macOS)
                                .controlSize(.small)
                                #endif
                        } else {
                            Text(String(localized: "清除"))
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isClearingCache)
            }
            #else
            Button(role: .destructive) {
                showingClearCacheAlert = true
            } label: {
                ZStack {
                    if isClearingCache {
                        ProgressView()
                            .tint(.red)
                    } else {
                        Text(String(localized: "清除所有图片缓存"))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .disabled(isClearingCache)
            #endif
        } header: {
            Text(String(localized: "缓存管理"))
        } footer: {
            Text(String(localized: "清除缓存后将重新下载图片，可能会消耗更多流量。"))
        }
    }

    private func loadCacheSize() async {
        do {
            let size = try await Kingfisher.ImageCache.default.diskStorageSize
            cacheSize = formatSize(Int(size))
        } catch {
            cacheSize = "获取失败"
        }
    }

    private func clearCache() async {
        guard !isClearingCache else { return }
        isClearingCache = true
        Kingfisher.ImageCache.default.clearMemoryCache()
        await Kingfisher.ImageCache.default.clearDiskCache()
        await loadCacheSize()
        isClearingCache = false
    }

    private func formatSize(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1024 / 1024
        if mb > 1024 {
            return String(format: "%.2f GB", mb / 1024)
        } else {
            return String(format: "%.2f MB", mb)
        }
    }
}

#Preview {
    NavigationStack {
        GeneralSettingsView()
    }
}
