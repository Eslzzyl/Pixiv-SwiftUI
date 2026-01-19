import SwiftUI

#if os(macOS)
struct MacOSPageNavigationOverlay: View {
    @Binding var currentPage: Int
    let totalPages: Int
    let isHovering: Bool
    
    var body: some View {
        HStack {
            Group {
                if currentPage > 0 {
                    leftButton
                } else {
                    Spacer().frame(width: 44, height: 44)
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale), removal: .opacity))
            
            Spacer()
                .allowsHitTesting(false)
            
            Group {
                if currentPage < totalPages - 1 {
                    rightButton
                } else {
                    Spacer().frame(width: 44, height: 44)
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale), removal: .opacity))
        }
        .padding(.horizontal, 16)
        .opacity(isHovering ? 1 : 0)
        .allowsHitTesting(isHovering)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .animation(.spring(response: 0.3), value: currentPage)
    }
    
    @ViewBuilder
    private var leftButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentPage -= 1
            }
        } label: {
            Image(systemName: "chevron.left")
                .font(.title2.weight(.medium))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.leftArrow, modifiers: [])
        .help("上一页")
    }
    
    @ViewBuilder
    private var rightButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentPage += 1
            }
        } label: {
            Image(systemName: "chevron.right")
                .font(.title2.weight(.medium))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.rightArrow, modifiers: [])
        .help("下一页")
    }
}
#endif
