import SwiftUI

struct SearchResultView: View {
    let word: String
    @ObservedObject var store: SearchStore
    @State private var selectedTab = 0
    @Environment(UserSettingStore.self) var settingStore
    
    private var filteredIllusts: [Illusts] {
        var result = store.illustResults
        if settingStore.userSetting.r18DisplayMode == 2 {
            result = result.filter { $0.xRestrict < 1 }
        }
        if settingStore.userSetting.blockAI {
            result = result.filter { $0.illustAIType != 2 }
        }
        return result
    }
    
    var body: some View {
        VStack {
            Picker("类型", selection: $selectedTab) {
                Text("插画").tag(0)
                Text("画师").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if store.isLoading {
                ProgressView()
                Spacer()
            } else if let error = store.errorMessage {
                ContentUnavailableView("出错了", systemImage: "exclamationmark.triangle", description: Text(error))
                Spacer()
            } else {
                if selectedTab == 0 {
                    // 插画瀑布流
                    ScrollView {
                        WaterfallGrid(data: filteredIllusts, columnCount: 2) { illust in
                            NavigationLink(destination: IllustDetailView(illust: illust)) {
                                IllustCard(illust: illust, columnCount: 2)
                            }
                        }
                    }
                } else {
                    // 画师列表
                    List(store.userResults) { userPreview in
                        NavigationLink(destination: UserDetailView(userId: userPreview.user.id.stringValue)) {
                            HStack {
                                if let urlString = userPreview.user.profileImageUrls?.medium, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { image in
                                        image.resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 50, height: 50)
                                            .clipShape(Circle())
                                    } placeholder: {
                                        Circle().fill(Color.gray.opacity(0.3))
                                            .frame(width: 50, height: 50)
                                    }
                                }
                                VStack(alignment: .leading) {
                                    Text(userPreview.user.name)
                                        .font(.headline)
                                    Text(userPreview.user.account)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle(word)
        .task {
            await store.search(word: word)
        }
    }
}
