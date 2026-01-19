import SwiftUI

struct SettingsRow<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        #if os(macOS)
        LabeledContent(label) {
            content.frame(maxWidth: 200)
        }
        .padding(.vertical, 4)
        #else
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.body)
            content
        }
        #endif
    }
}

#Preview {
    NavigationStack {
        Form {
            Section("图片质量") {
                SettingsRow("列表预览画质") {
                    Picker("", selection: .constant(0)) {
                        Text("中等").tag(0)
                        Text("大图").tag(1)
                        Text("原图").tag(2)
                    }
                    #if os(macOS)
                    .pickerStyle(.menu)
                    #else
                    .pickerStyle(.segmented)
                    #endif
                    .frame(width: 150)
                }

                SettingsRow("插画详情画质") {
                    Picker("", selection: .constant(1)) {
                        Text("中等").tag(0)
                        Text("大图").tag(1)
                        Text("原图").tag(2)
                    }
                    #if os(macOS)
                    .pickerStyle(.menu)
                    #else
                    .pickerStyle(.segmented)
                    #endif
                    .frame(width: 150)
                }
            }

            Section("布局") {
                SettingsRow("竖屏列数") {
                    Stepper("2 列", value: .constant(2), in: 2...5)
                }

                SettingsRow("横屏列数") {
                    Stepper("4 列", value: .constant(4), in: 2...6)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 600)
        .padding()
    }
}
