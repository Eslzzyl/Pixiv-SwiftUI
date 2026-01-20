import SwiftUI

struct SkeletonUserCard: View {
    let showFollowing: Bool
    
    init(showFollowing: Bool = false) {
        self.showFollowing = showFollowing
    }
    
    var body: some View {
        VStack(spacing: 4) {
            SkeletonCircle(size: 48)
            SkeletonView(height: 12, width: 50, cornerRadius: 2)
        }
        .frame(width: 60)
    }
}

struct SkeletonFollowingHorizontalList: View {
    let itemCount: Int
    
    init(itemCount: Int = 6) {
        self.itemCount = itemCount
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<itemCount, id: \.self) { _ in
                    SkeletonUserCard(showFollowing: true)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct SkeletonUserPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SkeletonCircle(size: 44)
                
                VStack(alignment: .leading, spacing: 2) {
                    SkeletonView(height: 14, width: 100, cornerRadius: 2)
                    SkeletonView(height: 12, width: 70, cornerRadius: 2)
                }
                
                Spacer()
                
                SkeletonCapsule(width: 60, height: 24)
            }
            .padding(.horizontal, 4)
            
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonRoundedRectangle(
                        height: 80,
                        cornerRadius: 6
                    )
                    .aspectRatio(1, contentMode: .fill)
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(12)
    }
}

struct SkeletonHorizontalUserGrid: View {
    let itemCount: Int
    
    init(itemCount: Int = 4) {
        self.itemCount = itemCount
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<itemCount, id: \.self) { _ in
                    SkeletonUserPreviewCard()
                        .frame(width: 300)
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview("User Card") {
    SkeletonUserCard(showFollowing: true)
        .padding()
}

#Preview("Following List") {
    SkeletonFollowingHorizontalList(itemCount: 6)
        .padding()
}

#Preview("User Preview Card") {
    SkeletonUserPreviewCard()
        .padding()
}
