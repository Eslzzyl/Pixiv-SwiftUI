import SwiftUI

struct NovelHorizontalList: View {
    let title: String
    let novels: [Novel]
    let listType: NovelListType
    @State private var isLoading = false
    @State private var hasAppeared = false
    @Environment(UserSettingStore.self) private var settingStore
    
    private var filteredNovels: [Novel] {
        settingStore.filterNovels(novels)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                NavigationLink(value: listType) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal)

            if isLoading && novels.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 140)
            } else if novels.isEmpty {
                HStack {
                    Spacer()
                    Text("暂无内容")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 100)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(filteredNovels.prefix(10)) { novel in
                            NavigationLink(value: novel) {
                                NovelCard(novel: novel)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            hasAppeared = true
            if novels.isEmpty {
                isLoading = true
            }
        }
        .onChange(of: novels.count) { _, newValue in
            if newValue > 0 {
                isLoading = false
            }
        }
    }
}

#Preview {
    let novels = [
        Novel(
            id: 123,
            title: "示例小说标题",
            caption: "",
            restrict: 0,
            xRestrict: 0,
            isOriginal: true,
            imageUrls: ImageUrls(
                squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg",
                medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
                large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
            ),
            createDate: "2023-12-15T00:00:00+09:00",
            tags: [],
            pageCount: 1,
            textLength: 15000,
            user: User(
                profileImageUrls: ProfileImageUrls(px50x50: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg"),
                id: StringIntValue.string("1"),
                name: "示例作者",
                account: "test_user"
            ),
            series: nil,
            isBookmarked: false,
            totalBookmarks: 1234,
            totalView: 56789,
            visible: true,
            isMuted: false,
            isMypixivOnly: false,
            isXRestricted: false,
            novelAIType: 0
        )
    ]
    
    NavigationStack {
        NovelHorizontalList(
            title: "推荐",
            novels: novels,
            listType: .recommend
        )
    }
}
