import SwiftUI
import RealityKit
import Combine

struct HomeView: View {
    // These @State variables are the "Brain" of the view.
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
    
    // Gesture State Variables
    @State private var lastDragTranslation: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1.0
    
    // Animation Timer: roughly 60 FPS
    let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top: 3D RealityKit View
            RealityView { content in
                if let loadedModel = try? await Entity(named: "Simple TARDIS") {
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
                    
                    loadedModel.generateCollisionShapes(recursive: true)
                    let rootEntity = Entity()
                    rootEntity.name = "TARDIS"
                    rootEntity.position = [0, -0.3, 0]
                    loadedModel.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
                    rootEntity.addChild(loadedModel)
                    
                    let anchor = AnchorEntity(world: .zero)
                    anchor.addChild(rootEntity)
                    content.add(anchor)
                }
            }
            update: { content in
                if let anchor = content.entities.first,
                   let rootEntity = anchor.children.first(where: { $0.name == "TARDIS" }) {
                    
                    rootEntity.scale = SIMD3<Float>(repeating: Float(modelScale))
                    
                    let rotX = simd_quatf(angle: Float(rotationX * .pi / 180), axis: [1, 0, 0])
                    let rotY = simd_quatf(angle: Float(rotationY * .pi / 180), axis: [0, 1, 0])
                    let rotZ = simd_quatf(angle: Float(rotationZ * .pi / 180), axis: [0, 0, 1])
                    rootEntity.orientation = rotZ * rotY * rotX

                    updateMaterial(for: "TARDIS_Mesh", color: modelColor)
                    updateMaterial(for: "Front_Windows_Mesh", color: frontWindowColor)
                    updateMaterial(for: "Top_Light_Glass_Mesh", color: topLightColor)
                    updateMaterial(for: "Left_Windows_Mesh", color: leftWindowColor)
                    updateMaterial(for: "Right_Windows_Mesh", color: rightWindowColor)
                    updateMaterial(for: "Rear_Windows_Mesh", color: rearWindowColor)
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color.black)
            .gesture(
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
                            modelScale *= Double(delta)
                            lastMagnification = value
                        }
                        .onEnded { _ in
                            lastMagnification = 1.0
                        }
                )
            )
            .onReceive(timer) { _ in
                rotationY += 0.5
                if rotationY >= 360 { rotationY -= 360 }
            }
            
            // MARK: - Bottom: Standard SwiftUI Controls
            ControlPanelView(
                modelScale: $modelScale,
                modelColor: $modelColor,
                frontWindowColor: $frontWindowColor,
                topLightColor: $topLightColor,
                leftWindowColor: $leftWindowColor,
                rightWindowColor: $rightWindowColor,
                rearWindowColor: $rearWindowColor
            )
            .background(.regularMaterial)
        }
        .ignoresSafeArea(.all, edges: .top)
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

#Preview {
    HomeView()
}
