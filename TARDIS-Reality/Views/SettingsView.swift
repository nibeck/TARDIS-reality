import SwiftUI


struct SettingsView: View {
    var body: some View {
        
        NavigationStack {
            List {
                Section("Preferences") {
                    Label("General", systemImage: "gear")
                    Label("Appearance", systemImage: "paintbrush")
                }
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Tests") {
                        HStack {
                            Button("Test LEDs") {
                                Task {
                                   //await viewModel.runTest()
                                }
                            }
                            .buttonStyle(.bordered)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }


#Preview {
    SettingsView()
}
