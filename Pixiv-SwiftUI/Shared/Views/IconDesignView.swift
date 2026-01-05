import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
struct AppIconView: View {
    // Pixiv 官方蓝色的现代化调整
    let pixivBlue = Color(red: 0.0, green: 0.58, blue: 0.98)
    let white = Color.white

    var body: some View {
        Text("P")
            .font(.system(size: 800, weight: .bold, design: .rounded))
            .foregroundStyle(white.gradient)
            .shadow(color: white.opacity(0.15), radius: 15, x: 0, y: 8)
            .offset(y: -10)
    }
}

struct IconExportView: View {
    var body: some View {
        VStack(spacing: 20) {
            AppIconView()
                .frame(width: 300, height: 300)
                .shadow(radius: 10)

            Text("Pixiv-SwiftUI 图标导出工具")
                .font(.headline)

            Button("导出 1024x1024 PNG (无 Alpha)") {
                exportToPNG()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(width: 500, height: 500)
    }

    @MainActor
    func exportToPNG() {
        // 1. 渲染 View
        let iconView = AppIconView().frame(width: 1024, height: 1024)
        let renderer = ImageRenderer(content: iconView)
        renderer.scale = 1.0

        guard let nsImage = renderer.nsImage else { return }

        // 2. 转换并去掉 Alpha 通道 (App Store 强制要求)
        guard let tiffData = nsImage.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            // 关键：创建一个不含 Alpha 的版本
            let noAlphaBitmap = bitmap.retaggingDefaultRGB()
        else { return }

        guard
            let pngData = noAlphaBitmap.representation(
                using: .png,
                properties: [:]
            )
        else { return }

        // 3. 弹出 macOS 保存对话框
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.nameFieldStringValue = "AppIcon_1024.png"
        savePanel.title = "保存图标"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try pngData.write(to: url)
                    print("✅ 成功导出到: \(url.path)")
                } catch {
                    print("❌ 保存失败: \(error)")
                }
            }
        }
    }
}

// 扩展：用于移除 Alpha 通道
extension NSBitmapImageRep {
    func retaggingDefaultRGB() -> NSBitmapImageRep? {
        // 创建一个没有 alpha 通道的位图上下文
        guard
            let cgImage = self.cgImage?.copy(
                colorSpace: CGColorSpaceCreateDeviceRGB(),
            )
        else { return nil }

        return NSBitmapImageRep(cgImage: cgImage)
    }
}
#endif
