import SwiftUI

struct TypeFilterButton: View {
    enum ContentType: String, CaseIterable {
        case all = "全部"
        case illust = "插画"
        case manga = "漫画"
    }

    @Binding var selectedType: ContentType
    var restrict: RestrictType?
    @Binding var selectedRestrict: RestrictType?

    enum RestrictType: String, CaseIterable {
        case publicAccess = "公开"
        case privateAccess = "非公开"
    }

    var body: some View {
        Menu {
            Section("内容类型") {
                ForEach(ContentType.allCases, id: \.self) { type in
                    Button {
                        selectedType = type
                    } label: {
                        HStack {
                            Text(type.rawValue)
                            if selectedType == type {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            if restrict != nil {
                Section("可见性") {
                    ForEach(RestrictType.allCases, id: \.self) { restrictType in
                        Button {
                            selectedRestrict = restrictType
                        } label: {
                            HStack {
                                Text(restrictType.rawValue)
                                if selectedRestrict == restrictType {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
    }
}

#Preview {
    TypeFilterButton(
        selectedType: .constant(.all),
        restrict: nil,
        selectedRestrict: .constant(nil as TypeFilterButton.RestrictType?)
    )
}
