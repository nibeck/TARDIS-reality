import SwiftUI
import RealityKit
import Combine
import Observation
import UIKit

// Renamed from HomeView to reflect that it is now just the 3D container
struct Tardis3DView: View {
    // The ViewModel is now passed in from the parent, sharing state with the controls
    var viewModel: TardisViewModel
    
    // Initial Rotation state variables (Degrees) - View-specific state
    @State private var rotationX: Double = 8 //103
    @State private var rotationY: Double = 32 //32
    @State private var rotationZ: Double = 0
    
    // Local scale state to isolate zoom gesture from affecting the shared ViewModel (and thus ControlsView)
    @State private var currentScale: Double = 0.6
    
    @State private var modelParts: [String: Entity] = [:]
    
    // Gesture State Variables
    @State private var lastDragTranslation: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1.0
    
    // Animation Timer: roughly 60 FPS
    let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    var body: some View {
        // MARK: - Top: 3D RealityKit View
        tardis3DView
            .onAppear {
                // Initialize local scale from ViewModel if needed, or keep default
                currentScale = viewModel.modelScale
            }
    }
    
    // MARK: - Subviews
    
    private var tardis3DView: some View {
        RealityView { content in
            do {
                // Attempt to load the model and catch errors if it fails
                let loadedModel = try await Entity(named: "TARDIS-new")
                
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
                
                // Manually apply textures to specific meshes that are missing them in the USDZ
                if let sign = parts["Sign_Mesh"] {
                    if var modelComp = sign.components[ModelComponent.self] {
                        do {
                            // Try to load and scale the texture using UIImage/CoreGraphics
                            var finalTexture: TextureResource?
                            
                            // Scale down by 15% (0.85) to fix "larger than mesh" issue
                            if let uiImage = UIImage(named: "Sign_Texture"),
                               let cgImage = uiImage.cgImage {
                                
                                let width = CGFloat(cgImage.width)
                                let height = CGFloat(cgImage.height)
                                let scale: CGFloat = 0.85
                                let newWidth = width * scale
                                let newHeight = height * scale
                                let xOffset = (width - newWidth) / 2
                                let yOffset = (height - newHeight) / 2
                                
                                let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
                                let scaledImage = renderer.image { _ in
                                    // Draw the image centered and scaled down
                                    uiImage.draw(in: CGRect(x: xOffset, y: yOffset, width: newWidth, height: newHeight))
                                }
                                
                                if let scaledCG = scaledImage.cgImage {
                                    finalTexture = try? TextureResource.generate(from: scaledCG, options: .init(semantic: .color))
                                }
                            }
                            
                            // Fallback to standard loading if image manipulation fails
                            if finalTexture == nil {
                                finalTexture = try TextureResource.load(named: "Sign_Texture")
                            }
                            
                            if let texture = finalTexture {
                                var material = PhysicallyBasedMaterial()
                                material.baseColor = .init(texture: .init(texture))
                                modelComp.materials = [material]
                                sign.components.set(modelComp)
                                print("Successfully applied Sign_Texture to Sign_Mesh")
                            }
                        } catch {
                            print("Error loading Sign_Texture: \(error)")
                        }
                    }
                }

                if let decal = parts["Circle_Decal"] {
                    if var modelComp = decal.components[ModelComponent.self] {
                        do {
                            let texture = try TextureResource.load(named: "Decal_Texture")
                            var material = PhysicallyBasedMaterial()
                            material.baseColor = .init(texture: .init(texture))
                            
                            // Decals usually need transparency.
                            // If the PNG has alpha, we need to enable blending.
                            material.blending = .transparent(opacity: .init(scale: 1.0))
                            
                            modelComp.materials = [material]
                            decal.components.set(modelComp)
                            print("Successfully applied Decal_Texture to Circle_Decal")
                        } catch {
                             print("Error loading Decal_Texture: \(error)")
                        }
                    }
                }
                
                Task { @MainActor in
                    self.modelParts = parts
                }
                
                loadedModel.generateCollisionShapes(recursive: true)
                let rootEntity = Entity()
                rootEntity.name = "TARDIS"
                
                // ADJUSTMENT: Changed Z to -1.5 to move the model further away from the camera.
                rootEntity.position = [0, -0.9, -1.5]
                
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
                
                // Use local currentScale instead of shared viewModel.modelScale
                rootEntity.scale = SIMD3<Float>(repeating: Float(currentScale))
                
                let rotX = simd_quatf(angle: Float(rotationX * .pi / 180), axis: [1, 0, 0])
                let rotY = simd_quatf(angle: Float(rotationY * .pi / 180), axis: [0, 1, 0])
                let rotZ = simd_quatf(angle: Float(rotationZ * .pi / 180), axis: [0, 0, 1])
                rootEntity.orientation = rotZ * rotY * rotX
                
                // Maps from mesh names in USDZ file to the appropriate color update function
                updateMaterial(for: "TARDIS_Mesh", color: viewModel.modelColor)
                updateMaterial(for: "Front_Windows_Mesh", color: viewModel.frontWindowColor)
                updateMaterial(for: "Top_Light_Light", color: viewModel.topLightColor)
                updateMaterial(for: "Left_Windows_Mesh", color: viewModel.leftWindowColor)
                updateMaterial(for: "Right_Windows_Mesh", color: viewModel.rightWindowColor)
                updateMaterial(for: "Rear_Windows_Mesh", color: viewModel.rearWindowColor)
                updateMaterial(for: "PoliceSignLight_Front", color: viewModel.frontPoliceSignColor)
                updateMaterial(for: "PoliceSignLight_Left", color: viewModel.leftPoliceSignColor)
                updateMaterial(for: "PoliceSignLight_Rear", color: viewModel.rearPoliceSignColor)
                updateMaterial(for: "PoliceSignLight_Right", color: viewModel.rightPoliceSignColor)
                
                // Update Model Opacity
                // print("Applying opacity: \(viewModel.modelOpacity)")
                let opacityComp = OpacityComponent(opacity: viewModel.modelOpacity)
                rootEntity.components.set(opacityComp)

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
                    // Update local currentScale instead of shared viewModel
                    let newScale = currentScale * Double(delta)
                    // Clamp scale to prevent it from vanishing or becoming too large
                    currentScale = min(max(newScale, 0.1), 5.0)
                    lastMagnification = value
                }
                .onEnded { _ in
                    lastMagnification = 1.0
                }
        )
    }
    
    private func updateMaterial(for partName: String, color: Color) {
        if let part = modelParts[partName],
           var modelComp = part.components[ModelComponent.self],
           !modelComp.materials.isEmpty {
            
            // Attempt to modify existing PhysicallyBasedMaterial (standard for USDZ)
            if var pbr = modelComp.materials[0] as? PhysicallyBasedMaterial {
                // Preserve existing texture if present, apply new color as tint
                pbr.baseColor = PhysicallyBasedMaterial.BaseColor(tint: UIColor(color), texture: pbr.baseColor.texture)
                
                // Write back
                modelComp.materials[0] = pbr
                part.components.set(modelComp)
            }
            // Attempt to modify existing SimpleMaterial
            else if var simple = modelComp.materials[0] as? SimpleMaterial {
                 // Preserve existing texture if present, apply new color as tint
                simple.color = .init(tint: UIColor(color), texture: simple.color.texture)
                
                // Write back
                modelComp.materials[0] = simple
                part.components.set(modelComp)
            }
            else {
                // Fallback for unhandled material types: replace with SimpleMaterial (destructive to textures)
                print("Warning: Could not preserve material type for \(partName). Replacing with SimpleMaterial.")
                var material = SimpleMaterial()
                material.color = .init(tint: UIColor(color))
                material.roughness = 0.2
                material.metallic = 0.8
                
                modelComp.materials = [material]
                part.components.set(modelComp)
            }
        }
    }
}

// MARK: - View Model
@Observable
class TardisViewModel {
    // Note: modelScale here is effectively the initial scale, or could be used for resets.
    // The gesture now updates a local state in Tardis3DView to avoid affecting UI controls.
    var modelScale: Double = 0.6
    var modelColor: Color = .blue
    
    var modelOpacity: Float {
        TARDISManager.shared.modelOpacity
    }
    
    var powerOnOff: Bool = false {
        didSet {
            // Update all individual toggles to match the master switch
            topLightOnOff = powerOnOff
            frontWindowOnOff = powerOnOff
            leftWindowOnOff = powerOnOff
            rightWindowOnOff = powerOnOff
            rearWindowOnOff = powerOnOff
            frontPoliceSignOnOff = powerOnOff
            leftPoliceSignOnOff = powerOnOff
            rearPoliceSignOnOff = powerOnOff
            rightPoliceSignOnOff = powerOnOff
            
            if powerOnOff {
                // Face 3d Model in
                TARDISManager.shared.fadeIn(duration: 2.0)
                // Fade LEDs out
                TARDISManager.shared.fadeLED(color: Color.white, duration: 3.0)
            } else {
                // Fade 3d model out
                TARDISManager.shared.fadeOut(duration: 2.0)
                // Fade LEDs out
                TARDISManager.shared.fadeLED(color: Color.black, duration: 3.0)
            }
        }
    }

    // Top Light
    var topLightOnOff: Bool = false {
        didSet {
            if topLightOnOff {
                TARDISManager.shared.turnOn(section: .topLight)
                topLightColor = .white
            } else {
                TARDISManager.shared.turnOff(section: .topLight)
            }
        }
    }
    var topLightColor: Color {
        get { TARDISManager.shared.sectionColors[.topLight] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .topLight, color: newValue) }
    }

    // Front Window
    var frontWindowOnOff: Bool = false {
        didSet {
            if frontWindowOnOff {
                TARDISManager.shared.turnOn(section: .frontWindow)
                frontWindowColor = .white
            } else {
                TARDISManager.shared.turnOff(section: .frontWindow)
            }
        }
    }
    var frontWindowColor: Color {
        get { TARDISManager.shared.sectionColors[.frontWindow] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .frontWindow, color: newValue) }
    }
    
    // Left Window
    var leftWindowOnOff: Bool = false {
        didSet {
            if leftWindowOnOff {
                TARDISManager.shared.turnOn(section: .leftWindow)
                leftWindowColor = .white
            } else {
                TARDISManager.shared.turnOff(section: .leftWindow)
            }
        }
    }
    var leftWindowColor: Color {
        get { TARDISManager.shared.sectionColors[.leftWindow] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .leftWindow, color: newValue) }
    }
    
    // Right Window
    var rightWindowOnOff: Bool = false {
        didSet {
            if rightWindowOnOff {
                TARDISManager.shared.turnOn(section: .rightWindow)
                rightWindowColor = .white
            } else {
                TARDISManager.shared.turnOff(section: .rightWindow)
            }
        }
    }
    var rightWindowColor: Color {
        get { TARDISManager.shared.sectionColors[.rightWindow] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .rightWindow, color: newValue) }
    }
    
    // Rear Window
    var rearWindowOnOff: Bool = false {
        didSet {
            if rearWindowOnOff {
                TARDISManager.shared.turnOn(section: .rearWindow)
                rearWindowColor = .white
            } else {
                TARDISManager.shared.turnOff(section: .rearWindow)
            }
        }
    }
    var rearWindowColor: Color {
        get { TARDISManager.shared.sectionColors[.rearWindow] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .rearWindow, color: newValue) }
    }
      
    // Front Police Sign
    var frontPoliceSignOnOff: Bool = false {
        didSet {
            if frontPoliceSignOnOff {
                TARDISManager.shared.turnOn(section: .frontPoliceSign)
                frontPoliceSignColor = .white
            } else {
                TARDISManager.shared.turnOff(section: .frontPoliceSign)
            }
        }
    }
    var frontPoliceSignColor: Color {
        get { TARDISManager.shared.sectionColors[.frontPoliceSign] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .frontPoliceSign, color: newValue) }
    }
    
    // Left Police Sign
    var leftPoliceSignOnOff: Bool = false {
        didSet {
            if leftPoliceSignOnOff {
                TARDISManager.shared.turnOn(section: .leftPoliceSign)
                leftPoliceSignColor = .white
            } else {
                TARDISManager.shared.turnOff(section: .leftPoliceSign)
            }
        }
    }
    var leftPoliceSignColor: Color {
        get { TARDISManager.shared.sectionColors[.leftPoliceSign] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .leftPoliceSign, color: newValue) }
    }
    
    // Rear Police Sign
    var rearPoliceSignOnOff: Bool = false {
        didSet {
            if rearPoliceSignOnOff {
                TARDISManager.shared.turnOn(section: .rearPoliceSign)
                rearPoliceSignColor = .white
            } else {
                TARDISManager.shared.turnOff(section: .rearPoliceSign)
            }
        }
    }
    var rearPoliceSignColor: Color {
        get { TARDISManager.shared.sectionColors[.rearPoliceSign] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .rearPoliceSign, color: newValue) }
    }
    
    // Right Police Sign
    var rightPoliceSignOnOff: Bool = false {
        didSet {
            if rightPoliceSignOnOff {
                TARDISManager.shared.turnOn(section: .rightPoliceSign)
                rightPoliceSignColor = .white
            } else {
                TARDISManager.shared.turnOff(section: .rightPoliceSign)
            }
        }
    }
    var rightPoliceSignColor: Color {
        get { TARDISManager.shared.sectionColors[.rightPoliceSign] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .rightPoliceSign, color: newValue) }
    }
    
    func runTest() async {
        await TARDISManager.shared.runTest()
    }
}
