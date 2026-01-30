import SwiftUI

struct BlockSettingView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    @State private var newTag = ""
    @State private var newUserId = ""
    @State private var newIllustId = ""

    var body: some View {
        Form {
            tagsSection
            usersSection
            illustsSection
        }
        .formStyle(.grouped)
    }

    private var tagsSection: some View {
        Section(String(localized: "屏蔽标签")) {
            if userSettingStore.blockedTagInfos.isEmpty && userSettingStore.blockedTags.isEmpty {
                Text(String(localized: "暂无屏蔽的标签"))
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(getTagInfos(), id: \.name) { info in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.name)
                                .font(.body)
                            if let translated = info.translatedName, !translated.isEmpty {
                                Text(translated)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button(action: {
                            triggerHaptic()
                            try? userSettingStore.removeBlockedTag(info.name)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack {
                TextField(String(localized: "添加标签"), text: $newTag)
                Button(String(localized: "添加")) {
                    if !newTag.isEmpty {
                        try? userSettingStore.addBlockedTag(newTag)
                        newTag = ""
                    }
                }
                .disabled(newTag.isEmpty)
            }
        }
    }

    private func getTagInfos() -> [BlockedTagInfo] {
        if !userSettingStore.blockedTagInfos.isEmpty {
            return userSettingStore.blockedTagInfos
        }
        return userSettingStore.blockedTags.map { BlockedTagInfo(name: $0, translatedName: nil) }
    }

    private var usersSection: some View {
        Section(String(localized: "屏蔽作者")) {
            if userSettingStore.blockedUserInfos.isEmpty && userSettingStore.blockedUsers.isEmpty {
                Text(String(localized: "暂无屏蔽的作者"))
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(getUserInfos(), id: \.userId) { info in
                    HStack(spacing: 12) {
                        if let avatarUrl = info.avatarUrl {
                            CachedAsyncImage(urlString: avatarUrl)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.name ?? info.userId)
                                .font(.body)
                            if let account = info.account {
                                Text("@\(account)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(info.userId)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button(action: {
                            triggerHaptic()
                            try? userSettingStore.removeBlockedUser(info.userId)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack {
                TextField(String(localized: "添加用户ID"), text: $newUserId)
                Button(String(localized: "添加")) {
                    if !newUserId.isEmpty {
                        try? userSettingStore.addBlockedUser(newUserId)
                        newUserId = ""
                    }
                }
                .disabled(newUserId.isEmpty)
            }
        }
    }

    private func getUserInfos() -> [BlockedUserInfo] {
        if !userSettingStore.blockedUserInfos.isEmpty {
            return userSettingStore.blockedUserInfos
        }
        return userSettingStore.blockedUsers.map { BlockedUserInfo(userId: $0, name: nil, account: nil, avatarUrl: nil) }
    }

    private var illustsSection: some View {
        Section(String(localized: "屏蔽插画")) {
            if userSettingStore.blockedIllustInfos.isEmpty && userSettingStore.blockedIllusts.isEmpty {
                Text(String(localized: "暂无屏蔽的插画"))
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(getIllustInfos(), id: \.illustId) { info in
                    HStack(spacing: 12) {
                        if let thumbnailUrl = info.thumbnailUrl {
                            CachedAsyncImage(urlString: thumbnailUrl)
                                .frame(width: 60, height: 60)
                                .cornerRadius(8)
                        } else {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .frame(width: 60, height: 60)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(info.title ?? "ID: \(info.illustId)")
                                .font(.body)
                                .lineLimit(2)
                            if let authorName = info.authorName {
                                Text(authorName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button(action: {
                            triggerHaptic()
                            try? userSettingStore.removeBlockedIllust(info.illustId)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack {
                TextField(String(localized: "添加插画ID"), text: $newIllustId)
                Button(String(localized: "添加")) {
                    if let id = Int(newIllustId) {
                        try? userSettingStore.addBlockedIllust(id)
                        newIllustId = ""
                    }
                }
                .disabled(Int(newIllustId) == nil)
            }
        }
    }

    private func getIllustInfos() -> [BlockedIllustInfo] {
        if !userSettingStore.blockedIllustInfos.isEmpty {
            return userSettingStore.blockedIllustInfos
        }
        return userSettingStore.blockedIllusts.map { BlockedIllustInfo(illustId: $0, title: nil, authorId: nil, authorName: nil, thumbnailUrl: nil) }
    }

    private func triggerHaptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}

#Preview {
    NavigationStack {
        BlockSettingView()
    }
    .frame(maxWidth: 600)
}
