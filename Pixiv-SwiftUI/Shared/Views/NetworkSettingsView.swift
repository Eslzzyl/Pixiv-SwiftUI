import SwiftUI

struct NetworkSettingsView: View {
    @ObservedObject private var networkModeStore = NetworkModeStore.shared

    var body: some View {
        Form {
            networkSection
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "网络"))
    }

    private var networkSection: some View {
        Section {
            LabeledContent(String(localized: "网络模式")) {
                Picker("", selection: $networkModeStore.currentMode) {
                    ForEach(NetworkMode.allCases) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }
        } header: {
            Text(String(localized: "网络"))
        } footer: {
            Text(networkModeStore.currentMode.description)
        }
    }
}

#Preview {
    NavigationStack {
        NetworkSettingsView()
    }
}
