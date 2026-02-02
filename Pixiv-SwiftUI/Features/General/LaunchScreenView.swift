import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            launchBackground
                .ignoresSafeArea()

            // 使用系统 AppIcon 的名称，确保从系统启动页到 SwiftUI 启动页的图标完全一致
            Image("launch")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
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
