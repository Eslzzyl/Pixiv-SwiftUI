import SwiftUI

struct FloatingCapsulePicker: View {
    @Binding var selection: String
    let options: [(label: String, value: String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                Button(action: { selection = option.value }) {
                    Text(option.label)
                        .font(.subheadline)
                        .fontWeight(selection == option.value ? .semibold : .regular)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selection == option.value ? Color.accentColor : Color.clear)
                        )
                        .foregroundColor(selection == option.value ? .white : .primary)
                }
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
        .padding(.horizontal)
    }
}
