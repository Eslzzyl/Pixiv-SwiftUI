import SwiftUI

struct LaunchScreenView: View {
    @State private var iconScale: CGFloat = 1.0
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            launchBackground
                .ignoresSafeArea()

            // 使用系统 AppIcon 的名称，确保从系统启动页到 SwiftUI 启动页的图标完全一致
            Image("launch")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .scaleEffect(iconScale)
                .opacity(opacity)
        }
        .onAppear {
            // 模拟图标轻微放大的连贯效果
            withAnimation(.easeOut(duration: 0.4)) {
                iconScale = 1.1
            }
        }
    }

    private var launchBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
}

#Preview {
    LaunchScreenView()
}
