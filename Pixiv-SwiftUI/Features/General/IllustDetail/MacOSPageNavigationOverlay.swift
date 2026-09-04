import SwiftUI

#if os(macOS)
struct MacOSPageNavigationOverlay: View {
    @Binding var currentPage: Int
    let totalPages: Int
    let isHovering: Bool

    private enum Direction {
        case left, right
        var systemImage: String { self == .left ? "chevron.left" : "chevron.right" }
        var help: String { self == .left ? "上一页" : "下一页" }
        var shortcut: KeyEquivalent { self == .left ? .leftArrow : .rightArrow }
    }

    var body: some View {
        HStack {
            Group {
                if currentPage > 0 {
                    pageButton(direction: .left)
                } else {
                    Spacer().frame(width: 32, height: 32)
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale), removal: .opacity))

            Spacer()
                .allowsHitTesting(false)

            Group {
                if currentPage < totalPages - 1 {
                    pageButton(direction: .right)
                } else {
                    Spacer().frame(width: 32, height: 32)
                }
            }
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale), removal: .opacity))
        }
        .padding(.horizontal, 8)
        .opacity(isHovering ? 1 : 0)
        .allowsHitTesting(isHovering)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .animation(.spring(response: 0.3), value: currentPage)
    }

    private func pageButton(direction: Direction) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if direction == .left {
                    currentPage -= 1
                } else {
                    currentPage += 1
                }
            }
        } label: {
            Image(systemName: direction.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 1)
                }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(direction.shortcut, modifiers: [])
        .help(direction.help)
        .accessibilityLabel(direction.help)
    }
}
#endif
