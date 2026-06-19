import SwiftUI

struct ImageTranslationPanelView: View {
    let store: ImageTranslationStore
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private var showCloseButton: Bool {
        switch store.phase {
        case .completed, .error: return true
        default: return false
        }
    }

    private var headerTitle: String {
        store.vlmExplanation.isEmpty ? "图片翻译" : "图片解释"
    }

    private var header: some View {
        HStack {
            Text(headerTitle)
                .font(.headline)

            Spacer()

            if showCloseButton {
                Button(action: {
                    store.reset()
                    onDismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .idle:
            emptyState
        case .loadingImage:
            loadingState("正在加载图片…")
        case .recognizingText:
            loadingState("正在识别文字…")
        case .analyzingWithVLM:
            loadingState("正在分析图片…")
        case .translating:
            translatingState
        case .completed:
            resultState
        case .error(let message):
            errorState(message)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView("选择图片开始翻译", systemImage: "text.bubble")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadingState(_ message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var translatingState: some View {
        VStack(spacing: 12) {
            ProgressView(value: store.progress)
                .progressViewStyle(.linear)
                .frame(width: 200)
            Text("正在翻译… \(Int(store.progress * 100))%")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultState: some View {
        Group {
            if !store.vlmExplanation.isEmpty {
                vlmResultState
            } else if store.segments.isEmpty {
                ContentUnavailableView("未识别到文字", systemImage: "text.magnifyingglass")
            } else {
                segmentResultState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var vlmResultState: some View {
        ScrollView {
            Text(store.vlmExplanation)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
    }

    private var segmentResultState: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.segments) { segment in
                    segmentRow(segment)
                    if segment.id != store.segments.last?.id {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func segmentRow(_ segment: ImageTranslationStore.TranslatedSegment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(segment.original)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Text(segment.translated)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                store.reset()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    ImageTranslationPanelView(
        store: {
            let store = ImageTranslationStore()
            store.segments = [
                .init(original: "桜の花が散る", translated: "樱花正在飘落"),
                .init(original: "もうすぐ春だね", translated: "马上就是春天了呢")
            ]
            store.phase = .completed
            return store
        }(),
        onDismiss: {}
    )
    .frame(width: 400, height: 300)
}

#Preview("VLM Result") {
    ImageTranslationPanelView(
        store: {
            let store = ImageTranslationStore()
            store.vlmExplanation = """
            ## 文字内容
            桜の花が散る → 樱花正在飘落
            もうすぐ春だね → 马上就是春天了呢

            ## 图片描述
            这是一张描绘春季樱花飘落的插画，画面中有一条被花瓣覆盖的小路。
            """
            store.phase = .completed
            return store
        }(),
        onDismiss: {}
    )
    .frame(width: 400, height: 300)
}
