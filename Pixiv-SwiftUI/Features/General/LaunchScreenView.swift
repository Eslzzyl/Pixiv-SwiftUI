import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                launchBackground
                    .ignoresSafeArea()

                Image("launch")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: geometry.size.width * 0.3,
                        height: geometry.size.width * 0.3
                    )
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
