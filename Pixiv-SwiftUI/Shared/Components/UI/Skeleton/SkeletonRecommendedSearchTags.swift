import SwiftUI

struct SkeletonRecommendedSearchTag: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SkeletonRoundedRectangle(width: 140, height: 140, cornerRadius: 16)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonView(height: 16, width: 80, cornerRadius: 2)
                        SkeletonView(height: 12, width: 60, cornerRadius: 2)
                    }
                    .padding(8)
                }
        }
    }
}

struct SkeletonRecommendedSearchTagsList: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("推荐标签")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { _ in
                        SkeletonRecommendedSearchTag()
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    SkeletonRecommendedSearchTagsList()
}
