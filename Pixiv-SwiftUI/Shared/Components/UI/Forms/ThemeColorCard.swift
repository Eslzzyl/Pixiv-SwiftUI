import SwiftUI

struct ThemeColorCard: View {
    let theme: ThemeColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(theme.color)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        )

                    if isSelected {
                        Circle()
                            .strokeBorder(theme.color, lineWidth: 2.5)
                            .frame(width: 48, height: 48)

                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(theme.onColor)
                    }
                }
                .frame(width: 48, height: 48)

                Text(LocalizedStringKey(theme.nameKey), bundle: .main)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 20) {
        ThemeColorCard(
            theme: ThemeColors.all[0],
            isSelected: true,
            action: {}
        )
        ThemeColorCard(
            theme: ThemeColors.all[1],
            isSelected: false,
            action: {}
        )
    }
    .padding()
}
