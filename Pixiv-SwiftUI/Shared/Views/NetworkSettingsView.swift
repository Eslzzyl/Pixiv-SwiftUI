import SwiftUI

struct NetworkSettingsView: View {
    @ObservedObject private var networkModeStore = NetworkModeStore.shared

    var body: some View {
        Form {
            networkSection
        }
        .formStyle(.grouped)
        .navigationTitle("网络")
    }

    private var networkSection: some View {
        Section {
            LabeledContent("网络模式") {
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
            Text("网络")
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
