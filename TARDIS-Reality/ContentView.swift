//
//  ContentView.swift
//  TARDIS-Reality
//
//  Created by Mike Nibeck on 12/24/25.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

struct HomeView: View {
    // State variables to control the 3D model
    @State private var modelColor: Color = .blue
    // Initialize scale to 0.6 as per the preferred default
    @State private var modelScale: Float = 0.6
    
    // Rotation state variables (Degrees)
    // Set initial rotation to X=277, Y=42
    @State private var rotationX: Double = 9
    @State private var rotationY: Double = 42
    @State private var rotationZ: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top: 3D RealityKit View
          
            RealityView { content in
                
                // Load the USDZ model asynchronously
                // Ensure "Tardis.usdz" is in your project and added to the target
                if let loadedModel = try? await ModelEntity(named: "Simple TARDIS") {
                    // Create a parent entity to act as the "pivot" for the model controls
                    let rootEntity = Entity()
                    rootEntity.name = "TARDIS"
                    rootEntity.position = [0, -0.3  , 0]
                    
                    // "Swap" Y and Z axes: Rotate the child model -90° (radians) on X
                    // This corrects models exported with Z-up to be Y-up in RealityKit
                    loadedModel.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
                    
                    rootEntity.addChild(loadedModel)
                    
                    let anchor = AnchorEntity(world: .zero)
                    anchor.addChild(rootEntity)
                    content.add(anchor)
                } else {
                    print("Failed to load model named 'Tardis'. Check filename.")
                }
            }
            update: { content in
                // This closure runs whenever the SwiftUI state (@State) changes
                
           
                
                // Find our model by name
                if let anchor = content.entities.first,
                   let modelEntity = anchor.children.first(where: { $0.name == "TARDIS" }) {
                    
                    // Update Scale
                    modelEntity.scale = SIMD3<Float>(repeating: modelScale)
                    
                    // Update Rotation
                    // Create quaternions for each axis (converting degrees to radians)
                    let rotX = simd_quatf(angle: Float(rotationX * .pi / 180), axis: [1, 0, 0])
                    let rotY = simd_quatf(angle: Float(rotationY * .pi / 180), axis: [0, 1, 0])
                    let rotZ = simd_quatf(angle: Float(rotationZ * .pi / 180), axis: [0, 0, 1])
                    
                    // Combine rotations (Order: X -> Y -> Z)
                    modelEntity.orientation = rotZ * rotY * rotX
                    
                    // Color Update Logic:
                    // Applying a SimpleMaterial here would overwrite your USDZ textures.
                    // If you want to tint it, you'd need to modify the materials more carefully.
                    // For now, we skip the color update to preserve the model's appearance.
                    /*
                    if let entityWithModel = modelEntity as? ModelEntity {
                        var material = SimpleMaterial()
                        material.color = .init(tint: UIColor(modelColor))
                        entityWithModel.model?.materials = [material]
                    }
                    */
                }
            }
            // Allow the 3D view to take up all available space not used by the controls
            .frame(maxHeight: .infinity)
            // Add a background color to distinguish the 3D area (useful in non-AR modes)
            .background(Color.black)
            
            // MARK: - Bottom: Standard SwiftUI Controls
            ScrollView {
                VStack(spacing: 10) {
                    Text("TARDIS Control Panel")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                    
                    // Color Control
                    // (Note: This won't affect the model unless you uncomment the logic above)
                    HStack {
                        Image(systemName: "paintpalette.fill")
                        Text("Hull Color")
                        Spacer()
                        ColorPicker("", selection: $modelColor)
                            .labelsHidden()
                    }
                    
                    // Scale Control
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                            Text("Size")
                            Spacer()
                            Slider(value: $modelScale, in: 0.5...3.0)
                            Text("\(String(format: "%.1f", modelScale))x")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Rotation Controls
                    Text("Rotation")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    rotationControl(axis: "X", value: $rotationX)
                    rotationControl(axis: "Y", value: $rotationY)
                    rotationControl(axis: "Z", value: $rotationZ)
                }
                .padding()
            }
            .background(.regularMaterial) // Glassy look for controls
        }
        .ignoresSafeArea(.all, edges: .top) // Let the 3D view go to the top edge
    }
    
    // Helper view builder for rotation sliders
    private func rotationControl(axis: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("\(axis) Axis")
                    .font(.caption)
                    .bold()
                Spacer()
                Slider(value: value, in: 0...360)
                Text("\(Int(value.wrappedValue))°")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

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
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
}
