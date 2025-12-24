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
    @State private var modelScale: Float = 1.0
    
    // Rotation state variables (Degrees)
    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0
    @State private var rotationZ: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top: 3D RealityKit View
            RealityView { content in
                // 1. Create a Mesh (Geometry)
                let mesh = MeshResource.generateBox(size: 0.2) // 20cm box
                
                // 2. Create a Material
                let material = SimpleMaterial(color: .blue, isMetallic: false)
                
                // 3. Create the ModelEntity
                let modelEntity = ModelEntity(mesh: mesh, materials: [material])
                modelEntity.name = "MainModel" // Naming it allows us to find it in the update closure
                
                // 4. Create an Anchor to place the model in the world
                // placing it 0.5 meters away (z: -0.5) and slightly up (y: 0.1)
                let anchor = AnchorEntity(world: .zero)
                modelEntity.position = [0, 0, -0.5]
                
                anchor.addChild(modelEntity)
                content.add(anchor)
                
            } update: { content in
                // This closure runs whenever the SwiftUI state (@State) changes
                
                // Find our model by name
                if let anchor = content.entities.first,
                   let modelEntity = anchor.children.first(where: { $0.name == "MainModel" }) as? ModelEntity {
                    
                    // Update Color
                    var material = SimpleMaterial()
                    material.color = .init(tint: UIColor(modelColor))
                    modelEntity.model?.materials = [material]
                    
                    // Update Scale
                    modelEntity.scale = SIMD3<Float>(repeating: modelScale)
                    
                    // Update Rotation
                    // Create quaternions for each axis (converting degrees to radians)
                    let rotX = simd_quatf(angle: Float(rotationX * .pi / 180), axis: [1, 0, 0])
                    let rotY = simd_quatf(angle: Float(rotationY * .pi / 180), axis: [0, 1, 0])
                    let rotZ = simd_quatf(angle: Float(rotationZ * .pi / 180), axis: [0, 0, 1])
                    
                    // Combine rotations (Order: X -> Y -> Z)
                    modelEntity.orientation = rotZ * rotY * rotX
                }
            }
            // Allow the 3D view to take up all available space not used by the controls
            .frame(maxHeight: .infinity)
            // Add a background color to distinguish the 3D area (useful in non-AR modes)
            .background(Color.black.opacity(0.8))
            
            // MARK: - Bottom: Standard SwiftUI Controls
            ScrollView {
                VStack(spacing: 20) {
                    Text("TARDIS Control Panel")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                    
                    // Color Control
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
                            Text("\(String(format: "%.1f", modelScale))x")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $modelScale, in: 0.5...3.0)
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
                // Add extra padding at the bottom so the last control isn't hidden behind the TabView
                .padding(.bottom, 20)
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
                Text("\(Int(value.wrappedValue))°")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 0...360)
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
