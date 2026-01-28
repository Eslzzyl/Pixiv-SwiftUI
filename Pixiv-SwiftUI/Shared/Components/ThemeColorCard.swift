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
                        .fill(Color(hex: theme.hex))
                        .frame(width: 44, height: 44)

                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 36, height: 36)

                    if isSelected {
                        Circle()
                            .stroke(Color(hex: theme.hex), lineWidth: 2)
                            .frame(width: 44, height: 44)

                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

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
