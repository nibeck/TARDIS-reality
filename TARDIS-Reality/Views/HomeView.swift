import SwiftUI
import RealityKit
import Combine
import Observation

// Renamed from HomeView to reflect that it is now just the 3D container
struct Tardis3DView: View {
    // The ViewModel is now passed in from the parent, sharing state with the controls
    var viewModel: TardisViewModel
    
    // Initial Rotation state variables (Degrees) - View-specific state
    @State private var rotationX: Double = 8 //103
    @State private var rotationY: Double = 32 //32
    @State private var rotationZ: Double = 0
    
    @State private var modelParts: [String: Entity] = [:]
    
    // Gesture State Variables
    @State private var lastDragTranslation: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1.0
    
    // Animation Timer: roughly 60 FPS
    let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    var body: some View {
        // MARK: - Top: 3D RealityKit View
        tardis3DView
    }
    
    // MARK: - Subviews
    
    private var tardis3DView: some View {
        RealityView { content in
            do {
                // Attempt to load the model and catch errors if it fails
                let loadedModel = try await Entity(named: "TARDIS")
                
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
                
                Task { @MainActor in
                    self.modelParts = parts
                }
                
                loadedModel.generateCollisionShapes(recursive: true)
                let rootEntity = Entity()
                rootEntity.name = "TARDIS"
                
                // ADJUSTMENT: Changed Y from -0.3 to -1.0 to move the model down.
                // Decrease this value (e.g. -1.5) to move it further down.
                // Increase this value (e.g. -0.5) to move it up.
                rootEntity.position = [0, -0.9, 0]
                
                loadedModel.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
                rootEntity.addChild(loadedModel)
                
                let anchor = AnchorEntity(world: .zero)
                anchor.addChild(rootEntity)
                content.add(anchor)
                
                let lightEntity = Entity()
                
                let redLightComponent = DirectionalLightComponent(
                    color: .white, intensity: 10_000
                )
                let lightShadowComponent = DirectionalLightComponent.Shadow()
                lightEntity.components.set([redLightComponent, lightShadowComponent])
                
                content.add(lightEntity)
                
            } catch {
                print("Error loading 'TARDIS': \(error)")
                print("Make sure 'TARDIS.usdz' is in the Project Navigator and 'Target Membership' is checked.")
            }
        }
        
        update: { content in
            if let anchor = content.entities.first,
               let rootEntity = anchor.children.first(where: { $0.name == "TARDIS" }) {
                
                rootEntity.scale = SIMD3<Float>(repeating: Float(viewModel.modelScale))
                
                let rotX = simd_quatf(angle: Float(rotationX * .pi / 180), axis: [1, 0, 0])
                let rotY = simd_quatf(angle: Float(rotationY * .pi / 180), axis: [0, 1, 0])
                let rotZ = simd_quatf(angle: Float(rotationZ * .pi / 180), axis: [0, 0, 1])
                rootEntity.orientation = rotZ * rotY * rotX

                updateMaterial(for: "TARDIS_Mesh", color: viewModel.modelColor)
                updateMaterial(for: "Front_Windows_Mesh", color: viewModel.frontWindowColor)
                updateMaterial(for: "Top_Light_Glass_Mesh", color: viewModel.topLightColor)
                updateMaterial(for: "Left_Windows_Mesh", color: viewModel.leftWindowColor)
                updateMaterial(for: "Right_Windows_Mesh", color: viewModel.rightWindowColor)
                updateMaterial(for: "Rear_Windows_Mesh", color: viewModel.rearWindowColor)
            }
        }
        .frame(maxHeight: .infinity)
        // MARK: - Background Image
        .background {
            // Ensure you have an image set named "SpaceBackground" in your Asset Catalog
            Image("Space-Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
        .gesture(combinedGesture)
        .onReceive(timer) { _ in
            rotationY += 0.5
            if rotationY >= 360 { rotationY -= 360 }
        }
    }
    
    private var combinedGesture: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged { value in
                    let deltaX = value.translation.width - lastDragTranslation.width
                    rotationY += Double(deltaX) * 0.5
                    lastDragTranslation = value.translation
                }
                .onEnded { _ in
                    lastDragTranslation = .zero
                },
            MagnificationGesture()
                .onChanged { value in
                    let delta = value / lastMagnification
                    viewModel.modelScale *= Double(delta)
                    lastMagnification = value
                }
                .onEnded { _ in
                    lastMagnification = 1.0
                }
        )
    }
    
    private func updateMaterial(for partName: String, color: Color) {
        if let part = modelParts[partName],
           var modelComp = part.components[ModelComponent.self] {
            var material = SimpleMaterial()
            material.color = .init(tint: UIColor(color))
            material.roughness = 0.2
            material.metallic = 0.8
            modelComp.materials = [material]
            part.components.set(modelComp)
        }
    }
}

// MARK: - View Model
@Observable
class TardisViewModel {
    var modelScale: Double = 0.6
    var modelColor: Color = .blue
    
    var allOnOff: Bool = false {
        didSet {
            if allOnOff {
                TARDISManager.shared.turnOn()
            } else {
                TARDISManager.shared.turnOff()
            }
        }
    }
    
    var frontWindowColor: Color = .yellow {
        didSet {
            TARDISManager.shared.setLightColor(for: .frontWindow, color: frontWindowColor)
        }
    }
    
    var topLightColor: Color = .white {
        didSet {
            TARDISManager.shared.setLightColor(for: .topLight, color: topLightColor)
        }
    }
    
    var leftWindowColor: Color = .white {
        didSet {
            TARDISManager.shared.setLightColor(for: .leftWindow, color: leftWindowColor)
        }
    }
    
    var rightWindowColor: Color = .white {
        didSet {
            TARDISManager.shared.setLightColor(for: .rightWindow, color: rightWindowColor)
        }
    }
    
    var rearWindowColor: Color = .white {
        didSet {
            TARDISManager.shared.setLightColor(for: .rearWindow, color: rearWindowColor)
        }
    }
}
