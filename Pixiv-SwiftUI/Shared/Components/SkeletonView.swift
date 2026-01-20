import SwiftUI

struct SkeletonModifier: ViewModifier {
    let isAnimating: Bool
    let animation: Animation
    
    init(isAnimating: Bool = true, animation: Animation = .linear(duration: 1.5).repeatForever(autoreverses: false)) {
        self.isAnimating = isAnimating
        self.animation = animation
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.gray.opacity(0.2),
                            Color.gray.opacity(0.5),
                            Color.gray.opacity(0.2)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: isAnimating ? -geometry.size.width : geometry.size.width)
                    .animation(animation, value: isAnimating)
                }
            )
            .mask(content)
    }
}

extension View {
    func skeleton(isAnimating: Bool = true) -> some View {
        modifier(SkeletonModifier(isAnimating: isAnimating))
    }
}

struct SkeletonView: View {
    let height: CGFloat
    let width: CGFloat?
    let cornerRadius: CGFloat
    
    init(height: CGFloat, width: CGFloat? = nil, cornerRadius: CGFloat = 4) {
        self.height = height
        self.width = width
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .skeleton()
    }
}

struct SkeletonCapsule: View {
    let width: CGFloat?
    let height: CGFloat
    
    init(width: CGFloat? = nil, height: CGFloat) {
        self.width = width
        self.height = height
    }
    
    var body: some View {
        Capsule()
            .fill(Color.gray.opacity(0.2))
            .frame(width: width, height: height)
            .skeleton()
    }
}

struct SkeletonRoundedRectangle: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.2))
            .frame(width: width, height: height)
            .skeleton()
    }
}

struct SkeletonCircle: View {
    let size: CGFloat
    
    init(size: CGFloat) {
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: size, height: size)
            .skeleton()
    }
}

#Preview {
    VStack(spacing: 20) {
        SkeletonView(height: 40, width: 200)
        SkeletonCircle(size: 60)
        SkeletonCapsule(width: 120, height: 30)
        SkeletonRoundedRectangle(width: 200, height: 100)
    }
    .padding()
}
