import SwiftUI

struct FullscreenImageView: View {
    let imageURLs: [String]
    let aspectRatios: [CGFloat]
    @Binding var initialPage: Int
    @Binding var isPresented: Bool
    var animation: Namespace.ID
    @State private var currentPage: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isZoomed: Bool = false

    private var dismissProgress: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        guard screenHeight > 0 else { return 0 }
        return min(dragOffset / screenHeight, 1.0)
    }

    private var scale: CGFloat {
        1.0 - dismissProgress * 0.3
    }

    private var backgroundOpacity: Double {
        1.0 - Double(dismissProgress)
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()

                TabView(selection: $currentPage) {
                    ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                        ZoomableAsyncImage(
                            urlString: url,
                            aspectRatio: index < aspectRatios.count ? aspectRatios[index] : nil,
                            onDismiss: {
                                isPresented = false
                            },
                            isZoomed: $isZoomed,
                            onDragProgress: { progress in
                                dragOffset = progress * UIScreen.main.bounds.height
                            },
                            onDragEnded: { shouldDismiss in
                                if shouldDismiss {
                                    isPresented = false
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                        )
                        .tag(index)
                    }
                }
                .ignoresSafeArea()
                #if canImport(UIKit)
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                #endif
                .scaleEffect(scale)
                .offset(y: dragOffset)

                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                    Spacer()

                    if imageURLs.count > 1 {
                        Text("\(currentPage + 1) / \(imageURLs.count)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .padding(.bottom, 20)
                    }
                }
                .opacity(Double(1 - dismissProgress * 2))
            }
        }
        .onAppear {
            currentPage = initialPage
        }
        .onChange(of: currentPage) { _, newValue in
            initialPage = newValue
            isZoomed = false
        }
        .onChange(of: isPresented) { _, newValue in
            if !newValue {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    dragOffset = 0
                }
            }
        }
    }
}
