import SwiftUI
import UniformTypeIdentifiers
import os.log

#if os(macOS)
import AppKit
#endif

// MARK: - Notifications
extension Notification.Name {
    static let novelExportDidComplete = Notification.Name("novelExportDidComplete")
}

struct NovelDetailView: View {
    let novel: Novel
    @State private var vm: NovelDetailViewModel
    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(AccountStore.self) var accountStore
    @Environment(ToastPresenter.self) var toast
    @Environment(\.colorScheme) private var colorScheme

    @State private var navigateToUserId: String?
    @State private var navigateToIllustId: Int?
    @State private var navigateToNovelId: Int?
    @State private var navigateToReaderId: Int?
    @State private var showAuthView = false
    @State private var showDeleteConfirmation = false
    @State private var isBlockTriggered: Bool = false

    #if os(iOS)
    @State private var showComments = false
    @State private var showDocumentPicker = false
    @State private var exportTempURL: URL?
    @State private var exportFilename: String = ""
    #endif
    #if os(macOS)
    @State private var coverAspectRatio: CGFloat = 0
    @AppStorage("macos_novel_detail_left_width") private var leftColumnWidth: Double = 0
    #endif

    @Environment(\.dismiss) private var dismiss

    init(novel: Novel) {
        self.novel = novel
        _vm = State(initialValue: NovelDetailViewModel(novel: novel))
    }

    var body: some View {
        GeometryReader { proxy in
            #if os(macOS)
            let totalWidth = proxy.size.width
            let dividerWidth: CGFloat = 8
            let minLeftWidth: CGFloat = 350
            let minRightWidth: CGFloat = 400
            let availableWidth = max(0, totalWidth - dividerWidth)
            let defaultLeftWidth = availableWidth * 0.6

            let storedLeftWidth: CGFloat? = leftColumnWidth > 0 ? CGFloat(leftColumnWidth) : nil
            let rawLeftWidth = storedLeftWidth ?? defaultLeftWidth
            let currentLeftWidth = max(minLeftWidth, min(rawLeftWidth, availableWidth - minRightWidth))
            let currentRightWidth = max(minRightWidth, availableWidth - currentLeftWidth)

            HStack(spacing: 0) {
                // Left Column: Cover and Tags (Main Content)
                ScrollView {
                    VStack(spacing: 0) {
                        NovelDetailCoverSection(
                            novel: vm.novelData,
                            coverAspectRatio: coverAspectRatio > 0 ? coverAspectRatio : nil,
                            onCoverSizeChange: { size in
                                guard size.width > 0, size.height > 0 else { return }
                                let newRatio = size.width / size.height
                                if abs(coverAspectRatio - newRatio) > 0.01 {
                                    coverAspectRatio = newRatio
                                }
                            },
                            onStartReading: {
                                navigateToReaderId = vm.novelData.id
                            }
                        )
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.trailing, 16)
                }
                .frame(width: currentLeftWidth)

                // Draggable Divider
                Color.clear
                    .frame(width: dividerWidth)
                    .overlay(
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 1)
                            .frame(maxHeight: .infinity)
                    )
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering {
                            #if os(macOS)
                            NSCursor.resizeLeftRight.push()
                            #endif
                        } else {
                            #if os(macOS)
                            NSCursor.pop()
                            #endif
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newWidth = currentLeftWidth + value.translation.width
                                if newWidth > minLeftWidth && newWidth < availableWidth - minRightWidth {
                                    leftColumnWidth = Double(newWidth)
                                }
                            }
                    )

                // Right Column: Info and Comments
                ScrollView {
                    VStack(spacing: 0) {
                        NovelDetailInfoSection(
                            novel: vm.novelData,
                            userSettingStore: userSettingStore,
                            accountStore: accountStore,
                            colorScheme: colorScheme,
                            isBookmarked: $vm.isBookmarked,
                            isFollowed: $vm.isFollowed,
                            totalComments: $vm.totalComments,
                            navigateToUserId: $navigateToUserId,
                            isCommentsPanelPresented: .constant(false)
                        )
                        .padding()

                        Divider()
                            .padding(.horizontal)

                        NovelCommentsPanelInlineView(
                            novel: vm.novelData,
                            onUserTapped: { userId in
                                navigateToUserId = userId
                            },
                            hasInternalScroll: false
                        )
                        .padding()

                        Spacer(minLength: 0)
                    }
                }
                .frame(width: currentRightWidth)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #else
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NovelDetailCoverSection(
                        novel: vm.novelData,
                        onStartReading: {
                            navigateToReaderId = vm.novelData.id
                        }
                    )
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                        .padding(.horizontal)

                    NovelDetailInfoSection(
                        novel: vm.novelData,
                        userSettingStore: userSettingStore,
                        accountStore: accountStore,
                        colorScheme: colorScheme,
                        isBookmarked: $vm.isBookmarked,
                        isFollowed: $vm.isFollowed,
                        totalComments: $vm.totalComments,
                        navigateToUserId: $navigateToUserId,
                        isCommentsPanelPresented: $showComments
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            #endif
        }
        .navigationTitle(novel.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { copyToClipboard(String(novel.id)) }) {
                        Label(String(localized: "复制 ID"), systemImage: "doc.on.doc")
                    }

                    if let shareURL = URL(string: "https://www.pixiv.net/novel/show.php?id=\(novel.id)") {
                        ShareLink(item: shareURL) {
                            Label(String(localized: "分享"), systemImage: "square.and.arrow.up")
                        }
                    }

                    Divider()

                    Menu {
                        Button(action: { vm.exportNovel(format: .txt) }) {
                            Label(String(localized: "导出为 TXT"), systemImage: "doc.text")
                        }
                        Button(action: { vm.exportNovel(format: .epub) }) {
                            Label(String(localized: "导出为 EPUB"), systemImage: "book.closed")
                        }
                    } label: {
                        Label(String(localized: "导出"), systemImage: "square.and.arrow.down")
                    }

                    if vm.isLoggedIn {
                        Divider()

                        Button(action: {
                            if vm.isBookmarked {
                                    vm.toggleBookmark(forceUnbookmark: true)                            } else {
                                    vm.toggleBookmark(isPrivate: userSettingStore.userSetting.defaultPrivateLike)                            }
                        }) {
                            Label(
                                vm.isBookmarked ? String(localized: "取消收藏") : String(localized: "收藏"),
                                systemImage: vm.isBookmarked ? "heart.fill" : "heart"
                            )
                        }

                        Divider()

                        Button(role: .destructive, action: {
                            isBlockTriggered = true
                            try? userSettingStore.addBlockedUserWithInfo(
                                novel.user.id.stringValue,
                                name: novel.user.name,
                                account: novel.user.account,
                                avatarUrl: novel.user.profileImageUrls?.medium
                            )
                            toast.show(String(localized: "已屏蔽作者"))
                            dismiss()
                        }) {
                            Label(String(localized: "屏蔽此作者"), systemImage: "person.slash")
                        }
                        .sensoryFeedback(.impact(weight: .medium), trigger: isBlockTriggered)

                        if vm.isOwnNovel {
                            Divider()

                            Button(role: .destructive, action: {
                                showDeleteConfirmation = true
                            }) {
                                Label(String(localized: "删除作品"), systemImage: "trash")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuIndicator(.hidden)
            }
        }
        .alert(String(localized: "确认删除"), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "取消"), role: .cancel) { }
            Button(String(localized: "删除"), role: .destructive) {
                Task {
                    await vm.deleteNovel()
                }
            }
            .disabled(vm.isDeleting)
        } message: {
            Text(String(localized: "删除后将无法恢复，确定要删除这个作品吗？"))
        }
        #if os(iOS)
        .sheet(isPresented: $showComments) {
            NovelCommentsPanelView(
                novel: vm.novelData,
                isPresented: $showComments,
                onUserTapped: { userId in
                    showComments = false
                    navigateToUserId = userId
                }
            )
        }
        .sheet(isPresented: $showDocumentPicker) {
            if let tempURL = exportTempURL {
                DocumentPickerView(tempURL: tempURL, filename: exportFilename)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .novelExportDidComplete)) { notification in
            guard let userInfo = notification.userInfo,
                  let tempURL = userInfo["tempURL"] as? URL,
                  let filename = userInfo["filename"] as? String else { return }
            self.exportTempURL = tempURL
            self.exportFilename = filename
            self.showDocumentPicker = true
        }
        #endif
        .onAppear {
            vm.showToast = { toast.show($0) }
            vm.onDismiss = { dismiss() }
            vm.fetchUserDetailIfNeeded()
            vm.fetchTotalCommentsIfNeeded()
            vm.recordGlance()
        }
        .navigationDestination(item: $navigateToUserId) { userId in
            UserDetailView(userId: userId)
        }
        .navigationDestination(item: $navigateToIllustId) { illustId in
            IllustLoaderView(illustId: illustId)
        }
        .navigationDestination(item: $navigateToNovelId) { novelId in
            NovelLoaderView(novelId: novelId)
        }
        .navigationDestination(item: $navigateToReaderId) { novelId in
            NovelReaderView(novelId: novelId)
        }
        .environment(\.openURL, OpenURLAction { url in
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                if url.scheme == "pixiv" {
                     let pathId = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                     if components.host == "illusts", let id = Int(pathId) {
                         navigateToIllustId = id
                         return .handled
                     } else if components.host == "users" {
                         navigateToUserId = pathId
                         return .handled
                       } else if components.host == "novel" || components.host == "novels", let id = Int(pathId) {
                          navigateToNovelId = id
                          return .handled
                      }
                } else if url.host?.contains("pixiv.net") == true {
                     let pathComponents = components.path.split(separator: "/")
                     if pathComponents.count >= 2 {
                         if pathComponents[0] == "artworks", let id = Int(pathComponents[1]) {
                             navigateToIllustId = id
                             return .handled
                         } else if pathComponents[0] == "users" {
                             navigateToUserId = String(pathComponents[1])
                             return .handled
                         }
                     }
                     if components.path.contains("novel/show.php"),
                        let idStr = components.queryItems?.first(where: { $0.name == "id" })?.value,
                        let id = Int(idStr) {
                         navigateToNovelId = id
                         return .handled
                     }
                }
            }
            return .systemAction
        })
        .sheet(isPresented: $showAuthView) {
            AuthView(accountStore: accountStore)
        }
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #else
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(text, forType: .string)
        #endif
        toast.show(String(localized: "已复制"))
    }

    #if os(macOS)
    private func showSavePanelForNovel(format: NovelExportFormat) {
        guard !vm.isExporting else { return }

        Task {
            let panel = NSSavePanel()
            switch format {
            case .txt:
                panel.allowedContentTypes = [.plainText]
            case .epub:
                if let epubType = UTType(filenameExtension: "epub") {
                    panel.allowedContentTypes = [epubType]
                }
            }
            panel.nameFieldStringValue = vm.exportFilename(format: format)
            panel.title = String(localized: "导出小说")

            let result = await withCheckedContinuation { continuation in
                panel.begin { response in
                    continuation.resume(returning: response)
                }
            }

            guard result == .OK, let url = panel.url else { return }
            vm.exportNovel(format: format, customSaveURL: url)
        }
    }
    #endif
}

#Preview {
    NavigationStack {
        NovelDetailView(novel: Novel(
            id: 123,
            title: "示例小说标题",
            caption: "这是一段小说简介，可以包含 HTML 标签。",
            restrict: 0,
            xRestrict: 0,
            isOriginal: true,
            imageUrls: ImageUrlsDTO(
                squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg",
                medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
                large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
            ),
            createDate: "2023-12-15T00:00:00+09:00",
            tags: [
                NovelTag(name: "原创", translatedName: nil, addedByUploadedUser: true),
                NovelTag(name: "ファンタジー", translatedName: "奇幻", addedByUploadedUser: true),
                NovelTag(name: "長編", translatedName: "长篇", addedByUploadedUser: false)
            ],
            pageCount: 1,
            textLength: 15000,
            user: UserDTO(
                profileImageUrls: ProfileImageUrlsDTO(
                    px50x50: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg"
                ),
                id: StringIntValue.string("1"),
                name: "示例作者",
                account: "test_user",
                mailAddress: nil,
                isPremium: nil,
                xRestrict: nil,
                isMailAuthorized: nil,
                requirePolicyAgreement: nil,
                isAcceptRequest: nil,
                isFollowed: nil
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
        ))
    }
}
