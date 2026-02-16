import SwiftUI
import Kingfisher

/// A specialized image component for user avatars that supports GIF animations on both iOS and macOS.
/// It automatically switches between KFImage and KFAnimatedImage based on the file extension.
public struct AnimatedAvatarImage: View {
    public let urlString: String?
    public let size: CGFloat
    public let placeholder: AnyView?
    public let expiration: CacheExpiration

    public init(
        urlString: String?,
        size: CGFloat,
        placeholder: AnyView? = nil,
        expiration: CacheExpiration = .days(7)
    ) {
        self.urlString = urlString
        self.size = size
        self.placeholder = placeholder
        self.expiration = expiration
    }

    private var isGIF: Bool {
        guard let urlString = urlString else { return false }
        // Pixiv profile images can be GIFs
        return urlString.lowercased().hasSuffix(".gif")
    }

    public var body: some View {
        imageContent
            .frame(width: size, height: size)
            .clipShape(Circle())
    }

    @ViewBuilder
    private var imageContent: some View {
        if let urlString = urlString, let url = URL(string: urlString), !urlString.isEmpty {
            if isGIF {
                // Use KFAnimatedImage for GIF support (especially on macOS)
                KFAnimatedImage(url)
                    .requestModifier(PixivImageLoader.shared)
                    .diskCacheExpiration(expiration.kingfisherExpiration)
                    .memoryCacheExpiration(expiration.kingfisherExpiration)
                    .fade(duration: 0.5)
                    .placeholder {
                        placeholderView
                    }
                    // KFAnimatedImage is resizable by default and doesn't support .resizable()
                    // in the same way as KFImage. It will fill the available space.
            } else {
                // Use standard KFImage for static images
                KFImage(url)
                    .requestModifier(PixivImageLoader.shared)
                    .diskCacheExpiration(expiration.kingfisherExpiration)
                    .memoryCacheExpiration(expiration.kingfisherExpiration)
                    .fade(duration: 0.5)
                    .placeholder {
                        placeholderView
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        } else {
            placeholderView
        }
    }

    @ViewBuilder
    private var placeholderView: some View {
        if let placeholder = placeholder {
            placeholder
        } else {
            Circle()
                .fill(Color.secondary.opacity(0.1))
                .frame(width: size, height: size)
        }
    }
}

#Preview {
    HStack {
        AnimatedAvatarImage(
            urlString: "https://i.pixiv.cat/img/user-img/1/1.jpg",
            size: 50
        )
        AnimatedAvatarImage(
            urlString: "https://example.com/animated.gif",
            size: 50
        )
    }
    .padding()
}
