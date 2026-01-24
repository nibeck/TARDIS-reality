import SwiftUI

struct TardisContentView: View {
    // State is now owned by the parent view
    @State private var viewModel = TardisViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Persistent 3D View (Top Half)
            Tardis3DView(viewModel: viewModel)
            
            // Swappable Tab Content (Bottom Half)
            TabView {
                ControlPanelView(viewModel: viewModel)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                AnimationView()
                    .tabItem {
                        Label("Animations", systemImage: "play.fill")
                    }
                
                ScenesView()
                    .tabItem {
                        Label("Scenes", systemImage: "lightbulb.fill")
                    }

                AudioView()
                    .tabItem {
                        Label("Audio", systemImage: "speaker.fill")
                    }
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
        }
        .ignoresSafeArea(.all, edges: .top) // Allows the 3D skybox/background to reach the top edge
    }
}

#Preview {
    TardisContentView()
}
