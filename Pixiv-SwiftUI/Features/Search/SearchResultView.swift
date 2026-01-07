import SwiftUI

struct SearchResultView: View {
    let word: String
    @StateObject var store = SearchStore()
    @State private var selectedTab = 0
    @Environment(UserSettingStore.self) var settingStore
    @Environment(\.dismiss) private var dismiss
    let instanceId = UUID()
    
    private var viewId: String {
        "\(instanceId)"
    }
    
    private var filteredIllusts: [Illusts] {
        settingStore.filterIllusts(store.illustResults)
    }
    
    private var filteredUsers: [UserPreviews] {
        settingStore.filterUserPreviews(store.userResults)
    }

    private var filteredNovels: [Novel] {
        settingStore.filterNovels(store.novelResults)
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Picker("类型", selection: $selectedTab) {
                    Text("插画").tag(0)
                    Text("小说").tag(1)
                    Text("画师").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .onChange(of: selectedTab) { _, newValue in
                    print("[SearchResultView] selectedTab changed to \(newValue)")
                }
                
                if selectedTab == 0 {
                    if filteredIllusts.isEmpty && !store.illustResults.isEmpty && settingStore.blockedTags.contains(word) {
                        VStack(spacing: 20) {
                            Spacer()
                            
                            Image(systemName: "eye.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("标签 \"\(word)\" 已被屏蔽")
                                .font(.title2)
                                .foregroundColor(.primary)
                            
                            Text("您已屏蔽此标签，因此没有显示相关插画")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button(action: {
                                try? settingStore.removeBlockedTag(word)
                            }) {
                                Text("取消屏蔽")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                            }
                            .buttonStyle(GlassButtonStyle(color: .blue))
                            
                            Spacer()
                        }
                        .padding()
                        .frame(minHeight: 300)
                    } else if filteredIllusts.isEmpty && !store.isLoading {
                        ContentUnavailableView("没有找到插画", systemImage: "magnifyingglass", description: Text("尝试搜索其他标签"))
                            .frame(minHeight: 300)
                    } else {
                        WaterfallGrid(data: filteredIllusts, columnCount: 2) { illust, columnWidth in
                            NavigationLink(value: illust) {
                                IllustCard(illust: illust, columnCount: 2, columnWidth: columnWidth)
                                    .onAppear {
                                        if illust.id == filteredIllusts.last?.id {
                                            Task {
                                                await store.loadMoreIllusts(word: word)
                                            }
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                } else if selectedTab == 1 {
                    if filteredNovels.isEmpty && !store.novelResults.isEmpty && !store.isLoading {
                        VStack(spacing: 20) {
                            Spacer()

                            Image(systemName: "book.closed")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)

                            Text("没有找到小说")
                                .font(.title2)
                                .foregroundColor(.primary)

                            Text("尝试搜索其他标签")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Spacer()
                        }
                        .frame(minHeight: 300)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredNovels) { novel in
                                NavigationLink(value: novel) {
                                    NovelListCard(novel: novel)
                                }
                                .buttonStyle(.plain)
                                .onAppear {
                                    if novel.id == filteredNovels.last?.id {
                                        Task {
                                            await store.loadMoreNovels(word: word)
                                        }
                                    }
                                }
                            }

                            if store.novelHasMore {
                                ProgressView()
                                    .padding()
                                    .onAppear {
                                        Task {
                                            await store.loadMoreNovels(word: word)
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    if filteredUsers.isEmpty && !store.userResults.isEmpty && !store.isLoading {
                        VStack(spacing: 20) {
                            Spacer()

                            Image(systemName: "eye.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)

                            Text("没有找到画师")
                                .font(.title2)
                                .foregroundColor(.primary)

                            Text("您已屏蔽所有搜索到的画师")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Spacer()
                        }
                        .frame(minHeight: 300)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredUsers, id: \.id) { userPreview in
                                NavigationLink(value: userPreview.user) {
                                    UserPreviewCard(userPreview: userPreview)
                                }
                                .buttonStyle(.plain)
                                .onAppear {
                                    if userPreview.id == filteredUsers.last?.id {
                                        Task {
                                            await store.loadMoreUsers(word: word)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .overlay {
            if store.isLoading && store.illustResults.isEmpty && store.userResults.isEmpty {
                ProgressView("加载中...")
            } else if let error = store.errorMessage, store.illustResults.isEmpty && store.userResults.isEmpty {
                ContentUnavailableView("出错了", systemImage: "exclamationmark.triangle", description: Text(error))
            }
        }
        .navigationTitle(word)
        .onAppear {
            print("[SearchResultView] Appeared: word='\(word)', viewId=\(viewId)")
        }
        .task {
            print("[SearchResultView] task started: word='\(word)', viewId=\(viewId)")
            if store.illustResults.isEmpty && store.novelResults.isEmpty && store.userResults.isEmpty {
                print("[SearchResultView] performing search")
                await store.search(word: word)
            } else {
                print("[SearchResultView] skipping search - results already exist")
            }
        }
        .onDisappear {
            print("[SearchResultView] disappeared: word='\(word)', viewId=\(viewId)")
        }
    }
}

#Preview {
    NavigationStack {
        SearchResultView(word: "测试")
    }
}
