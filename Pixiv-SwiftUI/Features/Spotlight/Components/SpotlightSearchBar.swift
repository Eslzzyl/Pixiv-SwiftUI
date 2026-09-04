import SwiftUI

struct SpotlightSearchBar: View {
    @Binding var text: String
    @Binding var isEditing: Bool
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool
    @Namespace private var glassNamespace

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            glassBody
        } else {
            legacyBody
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    private var glassBody: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                searchFieldContent
                    .frame(height: 44)
                    .padding(.horizontal, 12)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                    .glassEffectID("searchField", in: glassNamespace)

                if isEditing {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            text = ""
                            isFocused = false
                            isEditing = false
                            onCancel()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 44, height: 44)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .glassEffectID("closeButton", in: glassNamespace)
                    .accessibilityLabel(String(localized: "关闭"))
                }
            }
        }
        .onChange(of: isFocused) { _, newValue in
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditing = newValue
            }
        }
    }

    private var legacyBody: some View {
        HStack(spacing: 12) {
            searchFieldContent
                .padding(.vertical, 14)
                .padding(.horizontal, 6)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
                }

            if isEditing {
                Button {
                    text = ""
                    isFocused = false
                    isEditing = false
                    onCancel()
                } label: {
                    Text(String(localized: "取消"))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
        .onChange(of: isFocused) { _, newValue in
            isEditing = newValue
        }
    }

    private var searchFieldContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField(String(localized: "搜索特辑"), text: $text)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .onSubmit {
                    onSubmit(text)
                    isFocused = false
                }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    VStack {
        SpotlightSearchBar(
            text: .constant(""),
            isEditing: .constant(false),
            onSubmit: { _ in },
            onCancel: {}
        )
        .padding()

        SpotlightSearchBar(
            text: .constant("原神"),
            isEditing: .constant(true),
            onSubmit: { _ in },
            onCancel: {}
        )
        .padding()
    }
}
