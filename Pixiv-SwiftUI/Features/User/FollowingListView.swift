import SwiftUI

struct FollowingListView: View {
    @State var store: FollowingListStore
    @State private var isRefreshing: Bool = false
    let userId: String
    @Environment(AccountStore.self) var accountStore
    @Environment(ThemeManager.self) var themeManager

    @State private var columnCount: Int = 1
    @State private var selectedRestrict: TypeFilterButton.RestrictType? = .publicAccess

    private var restrictString: String {
        selectedRestrict == .privateAccess ? "private" : "public"
    }

    private var effectiveUserId: String {
        accountStore.currentUserId.isEmpty ? userId : accountStore.currentUserId
    }

    var body: some View {
        ScrollView {
            Group {
                if store.isLoadingFollowing && store.following.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount), spacing: 16) {
                        ForEach(0..<skeletonItemCount, id: \.self) { _ in
                            SkeletonUserCard()
                        }
                    }
                    .padding()
                    .transition(.opacity)
                } else if let error = store.error, store.following.isEmpty {
                    ErrorStateView(message: error.localizedDescription ?? "未知错误", retryAction: {
                        Task {
                            await store.fetchFollowing(userId: effectiveUserId, restrict: restrictString)
                        }
                    })
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else if store.following.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text(String(localized: "暂无关注用户"))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
                    .transition(.opacity)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount), spacing: 16) {
                        ForEach(store.following) { preview in
                            NavigationLink(value: preview.user.toDomain()) {
                                UserPreviewCard(userPreview: preview, accentColor: themeManager.currentColor)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if preview.id == store.following.last?.id && store.nextUrlFollowing != nil {
                                    Task {
                                        await store.loadMoreFollowing()
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .transition(.opacity)

                    if store.nextUrlFollowing != nil {
                        ProgressView()
                            #if os(macOS)
                            .controlSize(.small)
                            #endif
                            .padding()
                    } else if !store.following.isEmpty {
                        HStack {
                            Spacer()
                            Text(String(localized: "已经到底了"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.isLoadingFollowing)
        .refreshable {
            isRefreshing = true
            await store.refreshFollowing(userId: effectiveUserId, restrict: restrictString)
            isRefreshing = false
        }
        .responsiveUserGridColumnCount(columnCount: $columnCount)
        .onReceive(NotificationCenter.default.publisher(for: .refreshCurrentPage)) { _ in
            Task { @MainActor in
                isRefreshing = true
                await store.refreshFollowing(userId: effectiveUserId, restrict: restrictString)
                isRefreshing = false
            }
        }
        .navigationTitle(String(localized: "关注"))
        .sensoryFeedback(.impact(weight: .medium), trigger: isRefreshing)
        .toolbar {
            ToolbarItem {
                BookmarkVisibilityToggle(
                    selectedRestrict: $selectedRestrict,
                    isAvailable: true
                )
            }
            #if os(macOS)
            ToolbarItem {
                RefreshButton(refreshAction: {
                    isRefreshing = true
                    await store.refreshFollowing(userId: effectiveUserId, restrict: restrictString)
                    isRefreshing = false
                })
            }
            #endif
        }
        .onChange(of: selectedRestrict) { _, _ in
            Task {
                await store.refreshFollowing(userId: effectiveUserId, restrict: restrictString)
            }
        }
        .onChange(of: accountStore.accountGeneration) { _, _ in
            guard !effectiveUserId.isEmpty else { return }
            Task {
                await store.fetchFollowing(userId: effectiveUserId, restrict: restrictString, forceRefresh: true)
            }
        }
        .onAppear {
            if store.following.isEmpty {
                Task {
                    await store.fetchFollowing(userId: effectiveUserId, restrict: restrictString)
                }
            }
        }
    }

    private var skeletonItemCount: Int {
        #if os(macOS)
        12
        #else
        6
        #endif
    }
}
