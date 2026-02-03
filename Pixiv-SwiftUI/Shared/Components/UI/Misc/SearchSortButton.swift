import SwiftUI

enum SortContentType {
    case illust
    case novel
}

struct SearchSortButton: View {
    @Binding var sortOption: SearchSortOption
    var isPremium: Bool
    var contentType: SortContentType = .illust

    private var availableOptions: [SearchSortOption] {
        switch contentType {
        case .illust:
            return SearchSortOption.allCases
        case .novel:
            return [.dateDesc, .dateAsc]
        }
    }

    var body: some View {
        Menu {
            ForEach(availableOptions, id: \.self) { option in
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