import SwiftUI

struct AppIconView: View {
    // Pixiv 官方蓝色的现代化调整
    let pixivBlue = Color(red: 0.0, green: 0.58, blue: 0.98)
    
    var body: some View {
        ZStack {
            // 1. 背景：采用了方案 3 的微弱渐变，增加高级感
            LinearGradient(
                colors: [Color(white: 1.0), Color(white: 0.97)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 2. 主体 P：字重减为 .bold，设计更纤细优雅
            // 使用 ZStack 叠加一层微弱的投影，增加 macOS 风格的厚度感
            Text("P")
                .font(.system(size: 760, weight: .bold, design: .rounded))
                .foregroundStyle(
                    pixivBlue.gradient // 这里的渐变会让字母看起来有微弱的弧度
                )
                .shadow(color: pixivBlue.opacity(0.15), radius: 15, x: 0, y: 8)
                .offset(y: -10) // 视觉居中微调
        }
        .frame(width: 1024, height: 1024)
        // 注意：导出时不需要手动切圆角，App Store 会自动处理
    }
}

#Preview {
    AppIconView()
}
