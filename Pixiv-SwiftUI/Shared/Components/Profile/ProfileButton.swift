import SwiftUI

struct ProfileButton: View {
    @Bindable var accountStore: AccountStore
    @Binding var isPresented: Bool

    var body: some View {
        Button(action: { isPresented = true }) {
            if let account = accountStore.currentAccount, accountStore.isLoggedIn {
                CachedAsyncImage(urlString: account.userImage, idealWidth: 32, expiration: DefaultCacheExpiration.myAvatar)
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("我的")
    }
}
