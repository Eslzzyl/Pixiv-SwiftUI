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
        .navigationTitle("通用")
        .task {
            await loadCacheSize()
        }
        .alert("确认清除缓存", isPresented: $showingClearCacheAlert) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) {
                Task { await clearCache() }
            }
        } message: {
            Text("您确定要清除所有图片缓存吗？此操作不可撤销。")
        }
    }

    private var imageQualitySection: some View {
        Section {
            LabeledContent("列表预览画质") {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.feedPreviewQuality },
                    set: { try? userSettingStore.setFeedPreviewQuality($0) }
                )) {
                    Text("中等").tag(0)
                    Text("大图").tag(1)
                    Text("原图").tag(2)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.segmented)
                .frame(width: 150)
                #endif
            }

            LabeledContent("插画详情页画质") {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.pictureQuality },
                    set: { try? userSettingStore.setPictureQuality($0) }
                )) {
                    Text("中等").tag(0)
                    Text("大图").tag(1)
                    Text("原图").tag(2)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.segmented)
                .frame(width: 150)
                #endif
            }

            LabeledContent("大图预览画质") {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.zoomQuality },
                    set: { try? userSettingStore.setZoomQuality($0) }
                )) {
                    Text("中等").tag(0)
                    Text("大图").tag(1)
                    Text("原图").tag(2)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.segmented)
                .frame(width: 150)
                #endif
            }
        } header: {
            Text("图片质量")
        } footer: {
            Text("中等画质节省流量，大图画质更清晰，原图画质最高清（可能消耗更多流量）")
        }
    }

    private var layoutSection: some View {
        Section {
            LabeledContent("竖屏列数") {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.crossCount },
                    set: { try? userSettingStore.setCrossCount($0) }
                )) {
                    Text("1 列").tag(1)
                    Text("2 列").tag(2)
                    Text("3 列").tag(3)
                    Text("4 列").tag(4)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }

            LabeledContent("横屏列数") {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.hCrossCount },
                    set: { try? userSettingStore.setHCrossCount($0) }
                )) {
                    Text("2 列").tag(2)
                    Text("3 列").tag(3)
                    Text("4 列").tag(4)
                    Text("5 列").tag(5)
                    Text("6 列").tag(6)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }
        } header: {
            Text("布局")
        }
    }

    #if os(macOS)
    private var macOSSection: some View {
        Section {
            Toggle("关闭所有窗口后退出程序", isOn: Binding(
                get: { userSettingStore.userSetting.quitAfterWindowClosed },
                set: { try? userSettingStore.setQuitAfterWindowClosed($0) }
            ))
        } header: {
            Text("macOS 行为")
        }
    }
    #endif

    private var cacheSection: some View {
        Section {
            HStack {
                Text("图片缓存大小")
                Spacer()
                Text(cacheSize)
                    .foregroundColor(.secondary)
            }

            #if os(macOS)
            LabeledContent("清除缓存") {
                Button(role: .destructive) {
                    showingClearCacheAlert = true
                } label: {
                    HStack {
                        if isClearingCache {
                            ProgressView()
                        } else {
                            Text("清除")
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
                        Text("清除所有图片缓存")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .disabled(isClearingCache)
            #endif
        } header: {
            Text("缓存管理")
        } footer: {
            Text("清除缓存后将重新下载图片，可能会消耗更多流量。")
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
