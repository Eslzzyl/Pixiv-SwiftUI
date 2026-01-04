import SwiftUI

struct ProfileButton: View {
    @Bindable var accountStore: AccountStore
    @Binding var isPresented: Bool

    var body: some View {
        Button(action: { isPresented = true }) {
            if let account = accountStore.currentAccount {
                CachedAsyncImage(urlString: account.userImage, expiration: DefaultCacheExpiration.myAvatar)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("我的")
    }
}
