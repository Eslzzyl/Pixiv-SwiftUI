import SwiftUI

/// 屏蔽设置视图
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
        .navigationTitle("屏蔽设置")
    }
    
    private var tagsSection: some View {
        Section("屏蔽标签") {
            List {
                ForEach(userSettingStore.blockedTags, id: \.self) { tag in
                    HStack {
                        Text(tag)
                        Spacer()
                        Button(action: {
                            try? userSettingStore.removeBlockedTag(tag)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            HStack {
                TextField("添加标签", text: $newTag)
                Button("添加") {
                    if !newTag.isEmpty {
                        try? userSettingStore.addBlockedTag(newTag)
                        newTag = ""
                    }
                }
                .disabled(newTag.isEmpty)
            }
        }
    }
    
    private var usersSection: some View {
        Section("屏蔽作者") {
            List {
                ForEach(userSettingStore.blockedUsers, id: \.self) { userId in
                    HStack {
                        Text(userId)
                        Spacer()
                        Button(action: {
                            try? userSettingStore.removeBlockedUser(userId)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            HStack {
                TextField("添加用户ID", text: $newUserId)
                Button("添加") {
                    if !newUserId.isEmpty {
                        try? userSettingStore.addBlockedUser(newUserId)
                        newUserId = ""
                    }
                }
                .disabled(newUserId.isEmpty)
            }
        }
    }
    
    private var illustsSection: some View {
        Section("屏蔽插画") {
            List {
                ForEach(userSettingStore.blockedIllusts, id: \.self) { illustId in
                    HStack {
                        Text("\(illustId)")
                        Spacer()
                        Button(action: {
                            try? userSettingStore.removeBlockedIllust(illustId)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            HStack {
                TextField("添加插画ID", text: $newIllustId)
                Button("添加") {
                    if let id = Int(newIllustId) {
                        try? userSettingStore.addBlockedIllust(id)
                        newIllustId = ""
                    }
                }
                .disabled(Int(newIllustId) == nil)
            }
        }
    }
}

#Preview {
    BlockSettingView()
}