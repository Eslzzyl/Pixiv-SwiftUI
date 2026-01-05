import SwiftUI
import Kingfisher

struct UgoiraLoader: View {
    let illust: Illusts
    let expiration: CacheExpiration
    
    @StateObject private var store: UgoiraStore
    @Environment(UserSettingStore.self) private var userSettingStore
    @State private var showFullscreen = false
    
    init(illust: Illusts, expiration: CacheExpiration = .hours(1)) {
        self.illust = illust
        self.expiration = expiration
        self._store = StateObject(wrappedValue: UgoiraStore(illustId: illust.id, expiration: expiration))
    }
    
    private var aspectRatio: CGFloat {
        illust.safeAspectRatio
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
            
            statusOverlay
        }
        .onTapGesture {
            if store.isReady {
                showFullscreen = true
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showFullscreen) {
            UgoiraFullscreenView(
                store: store,
                isPresented: $showFullscreen,
                aspectRatio: aspectRatio,
                expiration: expiration
            )
        }
        #else
        .sheet(isPresented: $showFullscreen) {
            UgoiraFullscreenView(
                store: store,
                isPresented: $showFullscreen,
                aspectRatio: aspectRatio,
                expiration: expiration
            )
            .frame(minWidth: 600, minHeight: 800)
        }
        #endif
        .task {
            await store.loadIfNeeded()
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch store.status {
        case .idle, .downloading, .unzipping:
            thumbnailView
            
        case .ready, .playing:
            if store.isReady, !store.frameURLs.isEmpty {
                UgoiraView(
                    frameURLs: store.frameURLs,
                    frameDelays: store.frameDelays,
                    aspectRatio: aspectRatio,
                    expiration: expiration
                )
            } else {
                thumbnailView
            }
            
        case .error:
            thumbnailView
                .overlay(alignment: .center) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                }
        }
    }
    
    private var thumbnailView: some View {
        CachedAsyncImage(
            urlString: ImageURLHelper.getImageURL(from: illust, quality: userSettingStore.userSetting.pictureQuality),
            aspectRatio: aspectRatio
        )
        .clipped()
    }
    
    @ViewBuilder
    private var statusOverlay: some View {
        switch store.status {
        case .idle:
            playButton
            
        case .downloading(let progress):
            VStack(spacing: 8) {
                CircularProgressView(progress: progress)
                
                Button(action: { store.cancelDownload() }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Circle())
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
        case .unzipping:
            CircularProgressView(progress: nil)
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            
        case .ready, .playing:
            EmptyView()
            
        case .error:
            Button(action: { Task { await store.startDownload() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.orange.opacity(0.8))
                    .clipShape(Circle())
            }
            .padding(12)
        }
    }
    
    private var playButton: some View {
        Button(action: { Task { await store.startDownload() } }) {
            Image(systemName: "play.fill")
                .font(.title2)
                .foregroundColor(.white)
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .padding(12)
    }
}

struct UgoiraFullscreenView: View {
    @ObservedObject var store: UgoiraStore
    @Binding var isPresented: Bool
    let aspectRatio: CGFloat
    let expiration: CacheExpiration
    
    @State private var isPaused = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if store.isReady, !store.frameURLs.isEmpty {
                UgoiraView(
                    frameURLs: store.frameURLs,
                    frameDelays: store.frameDelays,
                    aspectRatio: aspectRatio,
                    expiration: expiration
                )
                .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }
            
            VStack {
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button(action: exportGIF) {
                            Label("导出 GIF", systemImage: "square.and.arrow.up")
                        }
                        
                        if !store.frameURLs.isEmpty {
                            Button(action: { isPaused.toggle() }) {
                                Label(
                                    isPaused ? "继续播放" : "暂停播放",
                                    systemImage: isPaused ? "play.fill" : "pause.fill"
                                )
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
            }
        }
    }
    
    private func exportGIF() {
        guard store.isReady, !store.frameURLs.isEmpty else { return }
        
        Task {
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(store.illustId)_ugoira.gif")
            
            do {
                try await GIFExporter.export(
                    frameURLs: store.frameURLs,
                    delays: store.frameDelays,
                    outputURL: outputURL
                )
                
                await MainActor.run {
                    showShareSheet(url: outputURL)
                }
            } catch {
                print("GIF 导出失败: \(error)")
            }
        }
    }
    
    private func showShareSheet(url: URL) {
        #if canImport(UIKit)
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #endif
    }
}

struct CircularProgressView: View {
    let progress: Double?
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                .frame(width: 50, height: 50)
            
            Circle()
                .trim(from: 0, to: CGFloat(progress ?? 0))
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.2), value: progress ?? 0)
            
            if let progress = progress {
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            } else {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
    }
}

#Preview {
    UgoiraLoader(illust: Illusts(
        id: 123,
        title: "测试",
        type: "ugoira",
        imageUrls: ImageUrls(
            squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg/img-master/d/2023/12/15/12/34/56/999999_p0_square1200.jpg",
            medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
            large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
        ),
        caption: "",
        restrict: 0,
        user: User(
            profileImageUrls: ProfileImageUrls(px16x16: "", px50x50: "", px170x170: ""),
            id: .string("1"),
            name: "测试",
            account: "test"
        ),
        tags: [],
        tools: [],
        createDate: "2023-12-15T00:00:00+09:00",
        pageCount: 1,
        width: 1200,
        height: 1600,
        sanityLevel: 2,
        xRestrict: 0,
        metaSinglePage: nil,
        metaPages: [],
        totalView: 1000,
        totalBookmarks: 500,
        isBookmarked: false,
        bookmarkRestrict: nil,
        visible: true,
        isMuted: false,
        illustAIType: 0
    ))
    .frame(width: 390, height: 520)
}
