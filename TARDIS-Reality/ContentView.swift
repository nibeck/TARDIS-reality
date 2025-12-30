//
//  ContentView.swift
//  TARDIS-Reality
//
//  Created by Mike Nibeck on 12/24/25.
//

import SwiftUI
import RealityKit
internal import Combine
import TARDISAPIClient
import OpenAPIRuntime
import OpenAPIURLSession

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
    // These @State variables are the "Brain" of the view.
    // Whenever one of these changes, SwiftUI looks for any code reading them and re-runs it.
    @State private var modelColor: Color = .blue
    @State private var frontWindowColor: Color = .yellow
    @State private var leftWindowColor: Color = .white
    @State private var rightWindowColor: Color = .white
    @State private var rearWindowColor: Color = .white
    @State private var topLightColor: Color = .white
    @State private var modelScale: Double = 0.6
    
    // Initial Rotation state variables (Degrees)
    @State private var rotationX: Double = 103
    @State private var rotationY: Double = 32
    @State private var rotationZ: Double = 0
    
    @State private var modelParts: [String: Entity] = [:]
    
    // API Client Setup
    private let client = Client(
        serverURL: URL(string: "http://192.168.1.161")!,
        transport: URLSessionTransport()
    )
    
    // Gesture State Variables
    @State private var lastDragTranslation: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1.0
    
    // Animation Timer: roughly 60 FPS
    let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top: 3D RealityKit View
          
            RealityView { content in
                // MARK: MAKE CLOSURE
                // This block runs ONLY ONCE when the view first appears.
                // We load the model and set up the initial scene here.
                if let loadedModel = try? await Entity(named: "Simple TARDIS") {
                    
                    // 1. CACHE PARTS: Traverse once and store references
                    var parts: [String: Entity] = [:]
                    
                    func collectParts(from entity: Entity) {
                        if entity.components.has(ModelComponent.self) {
                            parts[entity.name] = entity
                        }
                        for child in entity.children {
                            collectParts(from: child)
                        }
                    }
                    collectParts(from: loadedModel)
                    
                    self.modelParts = parts
                    
                    printCache(parts)
                    
                    print("--- Model Hierarchy ---")
                    printHierarchy(entity: loadedModel, depth: 0)
                    print("-----------------------")
                    
                    loadedModel.generateCollisionShapes(recursive: true)
                    
                    let rootEntity = Entity()
                    rootEntity.name = "TARDIS"
                    rootEntity.position = [0, -0.3, 0]
                    
                    loadedModel.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
                    
                    rootEntity.addChild(loadedModel)
                    
                    let anchor = AnchorEntity(world: .zero)
                    anchor.addChild(rootEntity)
                    content.add(anchor)
                } else {
                    print("Failed to load model named 'Simple TARDIS'. Check filename.")
                }
            }
            update: { content in
                // MARK: UPDATE CLOSURE (The Listener)
                // This block runs AUTOMATICALLY whenever any @State variable read inside it changes.
                
                if let anchor = content.entities.first,
                   let rootEntity = anchor.children.first(where: { $0.name == "TARDIS" }) {
                    
                    // Update Scale
                    // Reading 'modelScale' here subscribes this closure to changes in 'modelScale'
                    rootEntity.scale = SIMD3<Float>(repeating: Float(modelScale))
                    
                    // Update Rotation
                    let rotX = simd_quatf(angle: Float(rotationX * .pi / 180), axis: [1, 0, 0])
                    let rotY = simd_quatf(angle: Float(rotationY * .pi / 180), axis: [0, 1, 0])
                    let rotZ = simd_quatf(angle: Float(rotationZ * .pi / 180), axis: [0, 0, 1])
                    
                    rootEntity.orientation = rotZ * rotY * rotX

                    // Update TARDIS Color
                    if let windowPart = modelParts["TARDIS_Mesh"] {
                        if var modelComp = windowPart.components[ModelComponent.self] {
                            var material = SimpleMaterial()
                            material.color = .init(tint: UIColor(modelColor))
                            material.roughness = 0.2
                            material.metallic = 0.8
                            modelComp.materials = [material]
                            
                            windowPart.components.set(modelComp)
                        }
                    }
                    // Update Front window Color
                    if let windowPart = modelParts["Front_Windows_Mesh"] {
                        if var modelComp = windowPart.components[ModelComponent.self] {
                            var material = SimpleMaterial()
                            material.color = .init(tint: UIColor(frontWindowColor))
                            material.roughness = 0.2
                            material.metallic = 0.8
                            modelComp.materials = [material]
                            
                            windowPart.components.set(modelComp)
                        }
                    }
                    // Update Top Light Color
                    if let windowPart = modelParts["Top_Light_Glass_Mesh"] {
                        if var modelComp = windowPart.components[ModelComponent.self] {
                            var material = SimpleMaterial()
                            material.color = .init(tint: UIColor(topLightColor))
                            material.roughness = 0.2
                            material.metallic = 0.8
                            modelComp.materials = [material]
                            
                            windowPart.components.set(modelComp)
                        }
                    }
                    // Update Left Window Color
                    if let windowPart = modelParts["Left_Windows_Mesh"] {
                        if var modelComp = windowPart.components[ModelComponent.self] {
                            var material = SimpleMaterial()
                            material.color = .init(tint: UIColor(leftWindowColor))
                            material.roughness = 0.2
                            material.metallic = 0.8
                            modelComp.materials = [material]
                            
                            windowPart.components.set(modelComp)
                        }
                    }
                    // Update Right Window Color
                    if let windowPart = modelParts["Right_Windows_Mesh"] {
                        if var modelComp = windowPart.components[ModelComponent.self] {
                            var material = SimpleMaterial()
                            material.color = .init(tint: UIColor(rightWindowColor))
                            material.roughness = 0.2
                            material.metallic = 0.8
                            modelComp.materials = [material]
                            
                            windowPart.components.set(modelComp)
                        }
                    }
                    // Update Rear Window Color
                    if let windowPart = modelParts["Rear_Windows_Mesh"] {
                        if var modelComp = windowPart.components[ModelComponent.self] {
                            var material = SimpleMaterial()
                            material.color = .init(tint: UIColor(rearWindowColor))
                            material.roughness = 0.2
                            material.metallic = 0.8
                            modelComp.materials = [material]
                            
                            windowPart.components.set(modelComp)
                        }
                    }
                    
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color.black)
            .gesture(
                SimultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            let deltaX = value.translation.width - lastDragTranslation.width
                            // let deltaY = value.translation.height - lastDragTranslation.height
                            
                            rotationY += Double(deltaX) * 0.5
                            // rotationX += Double(deltaY) * 0.5 // Disabled X-axis rotation gesture
                            
                            lastDragTranslation = value.translation
                        }
                        .onEnded { _ in
                            lastDragTranslation = .zero
                        },
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastMagnification
                            modelScale *= Double(delta)
                            lastMagnification = value
                        }
                        .onEnded { _ in
                            lastMagnification = 1.0
                        }
                )
            )
            .onReceive(timer) { _ in
                // Increment rotationY to spin the object
                rotationY += 0.5
                // Keep the value within 0-360 range for cleanliness
                if rotationY >= 360 { rotationY -= 360 }
            }
            
            // MARK: - Bottom: Standard SwiftUI Controls
            ScrollView {
                VStack(spacing: 10) {
                    Text("TARDIS Control Panel")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                    
                    // Scale Control
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                            Text("Size")
                            Spacer()
                            // 2. THE TRIGGER:
                            // The Slider is bound to '$modelScale'. When you move it, 'modelScale' updates.
                            // This notifies the system, which triggers the 'update' closure above.
                            Slider(value: $modelScale, in: 0.5...3.0)
                            Text("\(String(format: "%.1f", modelScale))x")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Color Control
                    HStack {
                        Image(systemName: "paintpalette.fill")
                        Text("TARDIS Color")
                        Spacer()
                        ColorPicker("", selection: $modelColor)
                            .labelsHidden()
                    }
                    
                    // Window Color Control
                    HStack {
                        Image(systemName: "paintpalette.fill")
                        Text("Front Window Color")
                        Spacer()
                        ColorPicker("", selection: $frontWindowColor)
                            .labelsHidden()
                    }
                    // Top Light Control
                    HStack {
                        Image(systemName: "paintpalette.fill")
                        Text("Top Light Color")
                        Spacer()
                        ColorPicker("", selection: $topLightColor)
                            .labelsHidden()
                            .onChange(of: topLightColor) { _, newColor in
                                Task {
                                    let components = newColor.rgbComponents
                                    let body = Components.Schemas.Color(
                                        r: components.r,
                                        g: components.g,
                                        b: components.b
                                    )
                                    do {
                                        _ = try await client.set_color_api_led_color_post(body: .json(body))
                                    } catch {
                                        print("Failed to set LED color: \(error)")
                                    }
                                }
                            }
                    }
                    // Left Window
                    HStack {
                        Image(systemName: "paintpalette.fill")
                        Text("Left Window Color")
                        Spacer()
                        ColorPicker("", selection: $leftWindowColor)
                            .labelsHidden()
                    }
                    // Right Window
                    HStack {
                        Image(systemName: "paintpalette.fill")
                        Text("Right Window Color")
                        Spacer()
                        ColorPicker("", selection: $rightWindowColor)
                            .labelsHidden()
                    }
                    // Back Window
                    HStack {
                        Image(systemName: "paintpalette.fill")
                        Text("Rear Window Color")
                        Spacer()
                        ColorPicker("", selection: $rearWindowColor)
                            .labelsHidden()
                    }
                    
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
    
    // Helper to print cached parts
    private func printCache(_ parts: [String: Entity]) {
        print("--- Cached Model Parts (\(parts.count)) ---")
        for (name, _) in parts {
            print("Part found: \(name)")
        }
        print("----------------------------------")
    }
    
    // Debug helper to print model structure
    private func printHierarchy(entity: Entity, depth: Int) {
        let indent = String(repeating: "  ", count: depth)
        print("\(indent)- \(entity.name)")
        for child in entity.children {
            printHierarchy(entity: child, depth: depth + 1)
        }
    }
}

// MARK: - Color Extension
extension Color {
    var rgbComponents: (r: Int, g: Int, b: Int) {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return (
            r: Int(max(0, min(255, r * 255))),
            g: Int(max(0, min(255, g * 255))),
            b: Int(max(0, min(255, b * 255)))
        )
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
