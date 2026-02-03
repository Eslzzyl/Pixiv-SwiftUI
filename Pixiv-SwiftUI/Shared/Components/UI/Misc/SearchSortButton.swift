import SwiftUI

struct SearchSortButton: View {
    @Binding var sortOption: SearchSortOption
    var isPremium: Bool

    var body: some View {
        Menu {
            ForEach(SearchSortOption.allCases, id: \.self) { option in
                Button {
                    sortOption = option
                } label: {
                    HStack {
                        Text(option.displayName)
                        if sortOption == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .disabled(option.requiresPremium && !isPremium)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
    }
}

#Preview {
    SearchSortButton(
        sortOption: .constant(.dateDesc),
        isPremium: false
    )
}

#Preview("会员") {
    SearchSortButton(
        sortOption: .constant(.popularDesc),
        isPremium: true
    )
}