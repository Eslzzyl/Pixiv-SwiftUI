import SwiftUI

struct SpotlightWorkCard: View {
    let work: SpotlightWork
    let columnWidth: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                DynamicSizeCachedAsyncImage(
                    urlString: work.showImage,
                    contentMode: .fit
                )
                .frame(width: columnWidth)
                .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text(work.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)

                    Text(work.user)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            #endif
            .frame(width: columnWidth)
            .cornerRadius(16)
            .background(
                CardShadowView(
                    cornerRadius: 16,
                    shadowColor: .black.opacity(0.2),
                    shadowRadius: 2,
                    shadowOffset: CGSize(width: 0, height: 2)
                )
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                openInBrowser(urlString: work.artworkLink)
            } label: {
                Label(String(localized: "在浏览器中打开"), systemImage: "safari")
            }
        }
    }
}

struct SkeletonSpotlightWorkCard: View {
    let columnWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: columnWidth, height: columnWidth * 1.2)
                .skeleton()

            VStack(alignment: .leading, spacing: 4) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)
                    .skeleton()

                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: columnWidth * 0.4, height: 10)
                    .skeleton()
            }
            .padding(8)
        }
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        #endif
        .frame(width: columnWidth)
        .cornerRadius(16)
        .background(
            CardShadowView(
                cornerRadius: 16,
                shadowColor: .black.opacity(0.2),
                shadowRadius: 2,
                shadowOffset: CGSize(width: 0, height: 2)
            )
        )
    }
}

private func openInBrowser(urlString: String) {
    guard let url = URL(string: urlString) else { return }
    #if os(iOS)
    UIApplication.shared.open(url)
    #elseif os(macOS)
    NSWorkspace.shared.open(url)
    #endif
}

#Preview {
    guard let work = SpotlightWork(
        title: "時透無一郎",
        user: "ニャミ",
        userImage: "https://example.com/user.jpg",
        userLink: "https://www.pixiv.net/users/123",
        showImage: "https://example.com/image.jpg",
        artworkLink: "https://www.pixiv.net/artworks/123"
    ) else {
        return Text("Failed to create work")
    }

    return HStack(spacing: 12) {
        SpotlightWorkCard(work: work, columnWidth: 150) {}
        SpotlightWorkCard(work: work, columnWidth: 150) {}
    }
    .padding()
}
