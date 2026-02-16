import SwiftUI

struct ProfileButton: View {
    @Bindable var accountStore: AccountStore
    @Binding var isPresented: Bool

    var body: some View {
        Button(action: { isPresented = true }) {
            if let account = accountStore.currentAccount, accountStore.isLoggedIn {
                AnimatedAvatarImage(urlString: account.userImage, size: 28, expiration: DefaultCacheExpiration.myAvatar)
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
