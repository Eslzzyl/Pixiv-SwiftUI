import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct UpdateAvailableSheet: View {
    let updateInfo: AppUpdateInfo
    @Binding var isPresented: Bool
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)

            Text("发现新版本")
                .font(.title2)
                .fontWeight(.semibold)

            Text("v\(updateInfo.version)")
                .font(.headline)
                .foregroundColor(.secondary)

            ScrollView {
                Text(LocalizedStringKey(stringLiteral: updateInfo.releaseNotes))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            #if os(macOS)
            .frame(maxHeight: 200)
            #endif

            HStack(spacing: 12) {
                Button("关闭") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Button("跳过此版本") {
                    onSkip()
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Button("查看更新") {
                    if let url = URL(string: updateInfo.releaseUrl) {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(30)
        #if os(macOS)
        .frame(width: 420, height: 450)
        #endif
    }
}

#Preview {
    UpdateAvailableSheet(
        updateInfo: AppUpdateInfo(
            version: "0.11.2",
            releaseName: "v0.11.2",
            releaseNotes: """
            ## 新功能
            - **深色模式** 适配完成
            - 新增 *收藏夹* 分组功能
            - `API` 请求速度优化

            ## 修复
            - 修复了启动时[崩溃](https://github.com)的问题
            - 优化了图片加载性能

            > 感谢所有用户的反馈

            ### 技术细节
            1. 升级了 Kingfisher 到 8.x
            2. 重构了缓存层

            ```swift
            let x = 42
            print(x)
            ```
            """,
            releaseUrl: "https://github.com/Eslzzyl/Pixiv-SwiftUI/releases",
            downloadUrl: nil
        ),
        isPresented: .constant(true),
        onSkip: {}
    )
}
