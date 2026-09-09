import SwiftUI

/// 用户详情页头部骨架屏，与 UserDetailHeaderView + Tab 布局一致。
/// 在 store.isLoadingDetail 为 true 时展示，覆盖整个页面的骨架占位。
struct SkeletonUserDetailHeader: View {
    let columnCount: Int
    let itemCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. 背景图占位
            SkeletonRoundedRectangle(height: 200, cornerRadius: 0)
                .frame(maxWidth: .infinity)

            // 2. 头像 + 关注按钮行
            HStack(alignment: .bottom, spacing: 16) {
                SkeletonCircle(size: 80)
                    .offset(y: -40)
                    .padding(.bottom, -40)

                Spacer()

                SkeletonCapsule(width: 80, height: 36)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal)

            // 3. 昵称、统计、简介
            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(height: 22, width: 180, cornerRadius: 4)
                SkeletonView(height: 16, width: 120, cornerRadius: 3)

                SkeletonView(height: 16, cornerRadius: 3)
                SkeletonView(height: 16, width: 240, cornerRadius: 3)
            }
            .padding(.horizontal)

            // 4. 分段控件占位
            HStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonCapsule(height: 32)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()

            // 5. 内容区瀑布流骨架
            SkeletonIllustWaterfallGrid(
                columnCount: columnCount,
                itemCount: itemCount
            )
            .padding(.horizontal, 12)
        }
    }
}

#Preview {
    SkeletonUserDetailHeader(columnCount: 2, itemCount: 6)
}
