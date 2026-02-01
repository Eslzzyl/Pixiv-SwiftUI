import SwiftUI

struct SkeletonUserHorizontalList: View {
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

#Preview {
    VStack(spacing: 16) {
        Text("用户横向列表")
        SkeletonUserHorizontalList(itemCount: 6)
    }
    .padding()
}
