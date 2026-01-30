import SwiftUI

struct SkeletonHorizontalList: View {
    let itemCount: Int
    let itemHeight: CGFloat = 108

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<itemCount, id: \.self) { _ in
                    VStack(spacing: 4) {
                        SkeletonCircle(size: 48)
                        SkeletonView(height: 12, width: 40, cornerRadius: 2)
                    }
                    .frame(width: 60)
                }
            }
            .padding(.horizontal)
        }
    }
}

typealias SkeletonFollowingHorizontalList = SkeletonHorizontalList
typealias SkeletonNovelHorizontalList = SkeletonHorizontalList

#Preview {
    SkeletonHorizontalList(itemCount: 6)
        .padding()
}
