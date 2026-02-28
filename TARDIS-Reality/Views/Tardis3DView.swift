import SwiftUI        // Core SwiftUI framework for UI components and state management
import RealityKit     // Apple's AR/3D framework for rendering 3D content and entities
import Combine       // Reactive programming framework for handling timer and async events
import Observation   // Modern Swift observation framework replacing @ObservableObject
import UIKit         // Needed for UIImage manipulation and graphics rendering

/**
 * Tardis3DView: A specialized SwiftUI view responsible for rendering and managing the 3D TARDIS model
 * 
 * This view was renamed from HomeView to better reflect its single responsibility: managing the 3D
 * representation of the TARDIS model. It handles 3D model loading, material updates, user gestures,
 * and continuous rotation animation while maintaining separation from the control interface.
 * 
 * Key Design Decisions:
 * - Uses dependency injection to receive the shared ViewModel rather than creating its own
 * - Maintains its own gesture state to avoid interfering with parent view controls
 * - Implements a local scaling system that doesn't affect the shared ViewModel
 * - Uses RealityKit's Entity system for efficient 3D rendering and material management
 */
struct Tardis3DView: View {
    
    // MARK: - Dependency Injection
    /**
     * The ViewModel is injected from the parent view, creating a shared state model
     * between this 3D view and the control interface. This pattern allows:
     * - Consistent state management across multiple views
     * - Separation of concerns between 3D rendering and UI controls
     * - Easier testing and state debugging
     */
    var viewModel: TardisViewModel
    
    // MARK: - 3D Rotation State Management
    /**
     * These rotation variables control the 3D orientation of the TARDIS model in degrees.
     * They are view-specific because rotation should be independent of the control interface.
     * 
     * Initial values are carefully chosen to show the TARDIS at an appealing angle:
     * - rotationX: 8° provides a slight downward viewing angle
     * - rotationY: 32° shows the front-left corner prominently
     * - rotationZ: 0° keeps the model upright
     * 
     * Why @State: These values change frequently due to user gestures and animation,
     * requiring SwiftUI to re-render the view when they update.
     */
    @State private var rotationX: Double = 8
    @State private var rotationY: Double = 32
    @State private var rotationZ: Double = 0
    
    // MARK: - Local Scale Management
    /**
     * currentScale is deliberately separate from viewModel.modelScale to prevent
     * zoom gestures from interfering with the control interface. This creates:
     * - Smooth, uninterrupted zoom gestures
     * - No unwanted side effects on other UI components
     * - Better user experience with gesture handling
     * 
     * The initial value of 0.6 provides a good default size that fits well in the view.
     */
    @State private var currentScale: Double = 0.6
    
    // MARK: - 3D Model Component Cache
    /**
     * modelParts acts as a cache for individual 3D model components, enabling:
     * - Fast material updates without re-traversing the entire entity hierarchy
     * - Efficient color changes for specific parts (windows, lights, etc.)
     * - Better performance during real-time updates
     * 
     * The dictionary maps component names (from the USDZ file) to their Entity references.
     */
    @State private var modelParts: [String: Entity] = [:]
    
    // MARK: - Gesture State Tracking
    /**
     * These variables maintain gesture state between gesture events, enabling:
     * - Smooth, continuous drag operations
     * - Proper zoom gesture handling with momentum
     * - Prevention of gesture conflicts and jumping
     * 
     * lastDragTranslation: Tracks the previous drag position for delta calculations
     * lastMagnification: Stores the previous zoom level for relative scaling
     */
    @State private var lastDragTranslation: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1.0
    
    // MARK: - Continuous Animation System
    /**
     * The timer drives the automatic rotation animation at approximately 60 FPS.
     * This creates a smooth, continuous rotation that:
     * - Showcases the model from all angles
     * - Maintains visual interest when not being interacted with
     * - Runs on the main thread (.main) to ensure UI synchronization
     * - Uses .common run loop mode for consistent timing
     * - Auto-connects to start immediately when the view appears
     * 
     * The 0.02 second interval (50 FPS actual) balances smoothness with performance.
     */
    let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    // MARK: - SwiftUI Body
    /**
     * The main SwiftUI body that defines the view hierarchy and lifecycle.
     * This is kept minimal to maintain separation of concerns and readability.
     * 
     * onAppear: Initializes the local scale from the ViewModel when the view first appears.
     * This ensures consistency between the shared ViewModel and local gesture state.
     */
    var body: some View {
        // MARK: - Top: 3D RealityKit View
        tardis3DView
            .onAppear {
                // Initialize local scale from ViewModel if needed, or keep default
                currentScale = viewModel.modelScale
            }
    }
    
    // MARK: - 3D Scene Construction and Management
    /**
     * tardis3DView: The core 3D rendering component using RealityKit
     * 
     * This computed property encapsulates all 3D scene setup, model loading, material management,
     * and continuous updates. It's structured as a separate computed property to:
     * - Keep the main body clean and readable
     * - Separate 3D concerns from general view logic
     * - Make the code more maintainable and testable
     * 
     * RealityView is Apple's SwiftUI integration point for RealityKit, providing:
     * - Automatic view lifecycle management
     * - Integration with SwiftUI's rendering system
     * - Efficient updates when state changes
     * - Proper memory management for 3D resources
     */
    
    private var tardis3DView: some View {
        RealityView { content in
            // MARK: - Async Model Loading and Error Handling
            /**
             * This do-catch block handles the asynchronous loading of the 3D TARDIS model.
             * The async nature is necessary because:
             * - 3D models are large files that need to be loaded from storage
             * - Loading is performed on a background thread to avoid blocking the UI
             * - RealityKit needs time to parse and prepare the model for rendering
             * 
             * Error handling is crucial here because:
             * - Model files might be missing or corrupted
             * - Memory constraints could prevent loading
             * - File format issues could cause parsing failures
             */
            do {
                // Attempt to load the model and catch errors if it fails
                let loadedModel = try await Entity(named: "TARDIS-new")
                
                // MARK: - Model Component Discovery and Caching
                /**
                 * This section discovers and caches all renderable components in the 3D model.
                 * This is essential because:
                 * - USDZ files can contain complex hierarchies of nested entities
                 * - We need fast access to specific parts for real-time color updates
                 * - Building this cache once is more efficient than searching repeatedly
                 * 
                 * The recursive traversal ensures we find components at any depth in the hierarchy.
                 */
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
                
                // MARK: - Manual Texture Application for Sign Component
                /**
                 * This section manually applies textures to specific meshes that are missing them in the USDZ file.
                 * This is necessary because:
                 * - Some 3D modeling tools don't properly embed all texture references
                 * - USDZ export can sometimes lose texture assignments
                 * - We need pixel-perfect control over texture scaling and positioning
                 * 
                 * The Sign_Mesh requires special handling because the original texture is too large
                 * for the mesh, causing visual artifacts. The scaling solution:
                 * - Loads the original texture using UIImage for manipulation
                 * - Scales it down by 15% (0.85) to prevent overflow
                 * - Centers the scaled texture within the original dimensions
                 * - Converts it to RealityKit's TextureResource format
                 */
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

                // MARK: - Transparent Decal Texture Application
                /**
                 * The Circle_Decal component requires special material configuration for proper transparency.
                 * This is essential because:
                 * - Decals typically have transparent backgrounds (alpha channels)
                 * - Without proper blending mode, transparent areas would render as black
                 * - The decal needs to overlay on top of other model components
                 * 
                 * The .transparent blending mode ensures the PNG's alpha channel is respected,
                 * allowing the decal to properly composite with the underlying geometry.
                 */
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
                
                // MARK: - Thread-Safe Model Parts Cache Update
                /**
                 * This Task block safely transfers the model parts cache to the main thread.
                 * This is necessary because:
                 * - The parts dictionary was built on a background thread (RealityView context)
                 * - SwiftUI @State variables must be updated on the main thread
                 * - UI updates and material changes depend on this cache
                 * 
                 * The @MainActor annotation ensures this code runs on the main UI thread,
                 * preventing race conditions and ensuring thread safety.
                 */
                Task { @MainActor in
                    self.modelParts = parts
                }
                
                // MARK: - Physics and Collision Setup
                /**
                 * generateCollisionShapes creates invisible collision boundaries for the model.
                 * This is important for:
                 * - Future gesture interaction improvements (tap detection, etc.)
                 * - Proper physics simulation if needed later
                 * - Spatial understanding for AR features
                 * 
                 * The recursive flag ensures collision shapes are created for all child entities,
                 * not just the root model.
                 */
                loadedModel.generateCollisionShapes(recursive: true)
                
                // MARK: - Scene Hierarchy Setup
                /**
                 * This section creates a proper hierarchy for the 3D scene with careful positioning.
                 * The structure is: AnchorEntity -> rootEntity -> loadedModel
                 * 
                 * Why this hierarchy:
                 * - AnchorEntity provides world-space anchoring
                 * - rootEntity acts as a transform container for positioning and scaling
                 * - loadedModel contains the actual mesh data
                 * 
                 * This separation allows independent control of:
                 * - World positioning (AnchorEntity)
                 * - User transformations like scale and rotation (rootEntity)
                 * - Original model data (loadedModel)
                 */
                let rootEntity = Entity()
                rootEntity.name = "TARDIS"
                
                // Position the model in world space
                // Z: -1.5 moves the model away from camera for proper viewing distance
                // Y: -0.9 lowers the model so it appears centered vertically
                // X: 0.0 keeps the model centered horizontally
                rootEntity.position = [0, -0.9, -1.5]
                
                // Apply initial orientation correction
                // The model comes in at the wrong angle, so we rotate it -90° around X-axis
                // This corrects the "lying down" orientation to "standing up"
                loadedModel.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
                rootEntity.addChild(loadedModel)
                
                let anchor = AnchorEntity(world: .zero)
                anchor.addChild(rootEntity)
                content.add(anchor)

                // MARK: - Scene Lighting Setup
                /**
                 * Proper lighting is crucial for 3D model visibility and material rendering.
                 * This directional light setup provides:
                 * - Consistent illumination regardless of model rotation
                 * - High intensity (10,000) to ensure visibility in all orientations
                 * - White color for neutral, realistic lighting
                 * - Shadow support for depth perception
                 * 
                 * DirectionalLightComponent simulates sunlight - parallel rays from a distant source.
                 * This is ideal for showcasing the model's form and materials.
                 */
                let lightEntity = Entity()
                
                let redLightComponent = DirectionalLightComponent(
                    color: .white, intensity: 10_000
                )
                let lightShadowComponent = DirectionalLightComponent.Shadow()
                lightEntity.components.set([redLightComponent, lightShadowComponent])
                
                content.add(lightEntity)
                
            } catch {
                // MARK: - Model Loading Error Handling
                /**
                 * Comprehensive error handling for model loading failures.
                 * Common causes include:
                 * - Missing model file in the app bundle
                 * - Incorrect file name or path
                 * - Corrupted USDZ file
                 * - Memory constraints on device
                 * - Unsupported model format features
                 */
                print("Error loading 'TARDIS': \(error)")
                print("Make sure 'TARDIS.usdz' is in the Project Navigator and 'Target Membership' is checked.")
            }
        }
        
        // MARK: - Real-Time Update Loop
        /**
         * The update closure runs every frame to apply dynamic changes to the 3D scene.
         * This is where all real-time updates occur, including:
         * - Scale changes from gesture input
         * - Rotation updates from both gestures and automatic animation
         * - Material color changes from ViewModel updates
         * - Opacity changes for fade effects
         * 
         * This pattern separates one-time setup (in the main closure above) from
         * continuous updates (in this update closure).
         */
        update: { content in
            // Find our TARDIS entity in the scene hierarchy
            if let anchor = content.entities.first,
               let rootEntity = anchor.children.first(where: { $0.name == "TARDIS" }) {
                
                // MARK: - Dynamic Scale Application
                /**
                 * Apply the current scale from gesture input to all three dimensions.
                 * Using local currentScale instead of shared viewModel.modelScale
                 * prevents zoom gestures from interfering with control interface.
                 */
                rootEntity.scale = SIMD3<Float>(repeating: Float(currentScale))
                
                // MARK: - 3D Rotation Matrix Construction
                /**
                 * Convert rotation angles (in degrees) to quaternions and combine them.
                 * The order of multiplication matters:
                 * - rotZ * rotY * rotX applies rotations in the correct sequence
                 * - This prevents gimbal lock and ensures predictable rotation behavior
                 * 
                 * Each quaternion represents rotation around a single axis:
                 * - rotX: pitch (up/down rotation)
                 * - rotY: yaw (left/right rotation) - also driven by animation
                 * - rotZ: roll (twist rotation)
                 */
                let rotX = simd_quatf(angle: Float(rotationX * .pi / 180), axis: [1, 0, 0])
                let rotY = simd_quatf(angle: Float(rotationY * .pi / 180), axis: [0, 1, 0])
                let rotZ = simd_quatf(angle: Float(rotationZ * .pi / 180), axis: [0, 0, 1])
                rootEntity.orientation = rotZ * rotY * rotX
                
                // MARK: - Material Color Updates
                /**
                 * Update the visual appearance of specific model components based on ViewModel state.
                 * This mapping connects 3D mesh names (from the USDZ file) to ViewModel color properties.
                 * 
                 * Each updateMaterial call:
                 * - Finds the named mesh component in the model
                 * - Updates its material properties with the new color
                 * - Preserves existing textures while applying color tints
                 * 
                 * This system allows real-time color changes without rebuilding the entire model.
                 */
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
                
                // MARK: - Model Opacity Control
                /**
                 * Apply overall opacity to the entire model for fade effects.
                 * This is used for:
                 * - Power on/off animations
                 * - Dramatic lighting effects
                 * - Scene transitions
                 * 
                 * The OpacityComponent affects the entire entity hierarchy,
                 * creating smooth fade-in/fade-out effects for the whole model.
                 */
                let opacityComp = OpacityComponent(opacity: viewModel.modelOpacity)
                rootEntity.components.set(opacityComp)

            }
        }
        .frame(maxHeight: .infinity)
        // MARK: - Background Image Configuration
        /**
         * The background image creates an immersive space environment for the 3D model.
         * Configuration details:
         * - resizable(): Allows the image to scale to fill the available space
         * - scaledToFill(): Maintains aspect ratio while filling the entire background
         * - ignoresSafeArea(): Extends the image behind system UI elements like status bar
         * 
         * This creates a seamless space backdrop that enhances the sci-fi aesthetic
         * and provides visual context for the floating TARDIS model.
         */
        .background {
            // Ensure you have an image set named "SpaceBackground" in your Asset Catalog
            Image("Space-Background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
        // MARK: - Gesture Recognition System
        /**
         * The gesture system enables intuitive user interaction with the 3D model.
         * Using a simultaneous gesture recognizer allows both drag and zoom to work
         * independently and simultaneously for natural manipulation.
         */
        .gesture(combinedGesture)
        // MARK: - Continuous Animation Timer
        /**
         * The timer receiver drives the automatic rotation animation.
         * This creates the "showcase" effect where the model slowly rotates
         * to display all sides, even when the user isn't interacting with it.
         * 
         * The rotation speed (0.5° per frame at ~50 FPS) provides a gentle,
         * mesmerizing rotation that doesn't interfere with user interaction.
         */
        .onReceive(timer) { _ in
            rotationY += 0.5
            if rotationY >= 360 { rotationY -= 360 }
        }
    }
    
    // MARK: - Multi-Touch Gesture System
    /**
     * combinedGesture enables sophisticated multi-touch interaction with the 3D model.
     * 
     * SimultaneousGesture allows multiple gestures to operate at the same time:
     * - Users can drag to rotate AND pinch to zoom simultaneously
     * - This creates a natural, intuitive interaction model
     * - Prevents gesture conflicts and provides smooth user experience
     * 
     * The gesture system is carefully designed to:
     * - Maintain smooth interaction without jittering
     * - Preserve gesture momentum and natural feel
     * - Reset properly when gestures end
     * - Use delta-based calculations for precise control
     */
    private var combinedGesture: some Gesture {
        SimultaneousGesture(
            // MARK: - Rotation Drag Gesture
            /**
             * DragGesture enables model rotation through finger dragging.
             * 
             * Key implementation details:
             * - Uses delta calculations (current - previous) for smooth rotation
             * - Applies a 0.5 multiplier to prevent over-sensitive rotation
             * - Only affects rotationY (horizontal rotation) for predictable behavior
             * - Tracks lastDragTranslation to calculate movement deltas
             * 
             * This creates natural rotation that feels responsive but controlled.
             */
            DragGesture()
                .onChanged { value in
                    let deltaX = value.translation.width - lastDragTranslation.width
                    rotationY += Double(deltaX) * 0.5
                    lastDragTranslation = value.translation
                }
                .onEnded { _ in
                    lastDragTranslation = .zero
                },
            // MARK: - Zoom Magnification Gesture
            /**
             * MagnificationGesture enables intuitive pinch-to-zoom functionality.
             * 
             * Implementation strategy:
             * - Uses relative scaling (delta = current/previous) for smooth zoom
             * - Clamps scale between 0.1 and 5.0 to prevent extreme sizes
             * - Updates local currentScale to avoid UI interference
             * - Tracks lastMagnification for proper delta calculations
             * 
             * This provides natural zoom behavior that feels like manipulating a physical object.
             */
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
    
    // MARK: - Material Update System
    /**
     * updateMaterial provides real-time color updates for specific model components.
     * 
     * This function is crucial for the lighting system because it:
     * - Preserves existing textures while applying new color tints
     * - Handles different material types (PBR, Simple, etc.)
     * - Provides fallback behavior for unsupported material types
     * - Maintains visual quality while allowing dynamic color changes
     * 
     * Material Type Handling Strategy:
     * 1. First attempt: PhysicallyBasedMaterial (standard for USDZ files)
     * 2. Second attempt: SimpleMaterial (fallback for older formats)  
     * 3. Final fallback: Replace with SimpleMaterial (preserves functionality)
     * 
     * The function prioritizes preserving textures over color accuracy,
     * ensuring the model maintains its detailed appearance even during color changes.
     */
    private func updateMaterial(for partName: String, color: Color) {
        if let part = modelParts[partName],
           var modelComp = part.components[ModelComponent.self],
           !modelComp.materials.isEmpty {
            
            // MARK: - PhysicallyBasedMaterial Handling
            /**
             * PBR materials are the preferred format for high-quality 3D rendering.
             * They support:
             * - Physically accurate lighting calculations
             * - Complex texture combinations
             * - Realistic surface properties
             * 
             * When updating PBR materials, we preserve the existing texture
             * and apply the new color as a tint, maintaining visual richness.
             */
            if var pbr = modelComp.materials[0] as? PhysicallyBasedMaterial {
                // Preserve existing texture if present, apply new color as tint
                pbr.baseColor = PhysicallyBasedMaterial.BaseColor(tint: UIColor(color), texture: pbr.baseColor.texture)
                
                // Write back
                modelComp.materials[0] = pbr
                part.components.set(modelComp)
            }
            // MARK: - SimpleMaterial Fallback
            /**
             * SimpleMaterial provides basic rendering capabilities for older or
             * simplified 3D content. While less sophisticated than PBR materials,
             * they still support texture preservation and color tinting.
             */
            else if var simple = modelComp.materials[0] as? SimpleMaterial {
                 // Preserve existing texture if present, apply new color as tint
                simple.color = .init(tint: UIColor(color), texture: simple.color.texture)
                
                // Write back
                modelComp.materials[0] = simple
                part.components.set(modelComp)
            }
            else {
                // MARK: - Emergency Fallback Material
                /**
                 * When encountering unknown material types, we replace them with
                 * SimpleMaterial to maintain functionality. This is destructive
                 * to textures but ensures the lighting system continues to work.
                 * 
                 * Material properties:
                 * - roughness: 0.2 (slightly glossy surface)
                 * - metallic: 0.8 (metallic appearance for sci-fi aesthetic)
                 */
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

// MARK: - ViewModel: Application State and Business Logic
/**
 * TardisViewModel serves as the central state management system for the TARDIS application.
 * 
 * This class implements the MVVM (Model-View-ViewModel) pattern and provides:
 * - Centralized state management for all app components
 * - Clean separation between UI logic and business logic  
 * - Observable state changes for reactive UI updates
 * - Coordination between 3D model display and hardware control
 * 
 * Key Design Principles:
 * - Single source of truth for all lighting state
 * - Consistent behavior between UI controls and hardware commands
 * - Thread-safe operations with proper concurrency handling
 * - Graceful handling of power state transitions
 * 
 * The @Observable macro provides modern SwiftUI state management,
 * automatically triggering view updates when properties change.
 */
@Observable
class TardisViewModel {
    // MARK: - 3D Model Configuration Properties
    /**
     * These properties control the basic appearance and behavior of the 3D model display.
     * They are separate from the lighting system to maintain clear separation of concerns.
     */
    
    /**
     * modelScale: Represents the initial/default scale for the 3D model.
     * Note: The actual zoom behavior uses local state in Tardis3DView to prevent
     * gesture interference with the UI controls. This value serves as a reference
     * point and could be used for reset functionality.
     */
    var modelScale: Double = 0.6
    
    /**
     * modelColor: Controls the base color of the TARDIS structure itself.
     * This affects the main body/shell color but not the lighting elements,
     * maintaining the classic blue TARDIS appearance by default.
     */
    var modelColor: Color = .blue

    /**
     * modelOpacity: Computed property that retrieves opacity from TARDISManager.
     * This enables fade-in/fade-out effects for the entire 3D model during
     * power transitions and special effects. The computed property pattern
     * ensures the UI always reflects the current hardware state.
     */
    var modelOpacity: Float {
        TARDISManager.shared.modelOpacity
    }

    // MARK: - Power State Coordination System
    /**
     * isUpdatingFromPowerSwitch: Critical flag for preventing feedback loops.
     * 
     * This flag ensures that when the master power switch triggers changes,
     * the individual light section updates don't cause conflicting hardware commands.
     * Without this flag, turning on power would cause:
     * 1. Master switch triggers fade-in commands
     * 2. Individual sections receive state updates
     * 3. Individual sections trigger immediate-on commands
     * 4. Hardware receives conflicting fade AND immediate commands
     * 
     * The flag creates a communication protocol between the master switch
     * and individual sections, ensuring coordinated behavior.
     */
    private var isUpdatingFromPowerSwitch: Bool = false

    // MARK: - Master Power Control System
    /**
     * powerOnOff: The master switch that controls the entire TARDIS lighting system.
     * 
     * This property orchestrates complex state transitions involving:
     * - 3D model fade effects (visual feedback)
     * - Hardware LED fade commands (physical lighting)
     * - Individual section state synchronization
     * - UI control state updates
     * 
     * Power On Sequence:
     * 1. Start 3D model fade-in animation (2 seconds)
     * 2. Set coordination flag to prevent feedback loops
     * 3. Update all individual section toggles (triggers fade commands)
     * 4. Update UI color picker states to show target colors
     * 5. Clear coordination flag
     * 
     * Power Off Sequence:
     * 1. Start 3D model fade-out animation (2 seconds)
     * 2. Start global LED fade-out (3 seconds, creates smooth transition)
     * 3. Update individual section states with coordination flag
     * 
     * This design ensures smooth, coordinated transitions that look professional
     * and avoid jarring instant on/off behavior.
     */
    var powerOnOff: Bool = false {
        didSet {
            if powerOnOff {
                // Fade 3d Model in
                TARDISManager.shared.fadeIn(duration: 2.0)
                
                // Set flag to indicate programmatic updates are happening
                isUpdatingFromPowerSwitch = true

                // Update all individual toggles to match the master switch
                // This will trigger the individual didSet handlers which will handle both:
                // 1. The LED fade commands
                // 2. The UI color state updates
                topLightOnOff = powerOnOff
                frontWindowOnOff = powerOnOff
                leftWindowOnOff = powerOnOff
                rightWindowOnOff = powerOnOff
                rearWindowOnOff = powerOnOff
                frontPoliceSignOnOff = powerOnOff
                leftPoliceSignOnOff = powerOnOff
                rearPoliceSignOnOff = powerOnOff
                rightPoliceSignOnOff = powerOnOff

                // Clear flag after updating all toggles
                isUpdatingFromPowerSwitch = false
            } else {
                // Fade 3d model out
                TARDISManager.shared.fadeOut(duration: 2.0)
                // Fade all LEDs out immediately (global fade)
                TARDISManager.shared.fadeLED(color: Color.black, duration: 3.0)
                
                // Set flag to indicate programmatic updates are happening
                isUpdatingFromPowerSwitch = true

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

                // Clear flag after updating all toggles
                isUpdatingFromPowerSwitch = false
            }
        }
    }

    // MARK: - Individual Light Section Control System
    /**
     * The following section contains individual control properties for each physical lighting
     * component of the TARDIS. Each section follows a consistent pattern that provides:
     * 
     * - Toggle control (on/off state)
     * - Color selection (with real-time hardware updates)
     * - Coordinated behavior with the master power switch
     * - Smooth fade effects vs. immediate response based on context
     * 
     * Architecture Pattern for Each Section:
     * 1. OnOff Property: Boolean toggle with sophisticated didSet logic
     * 2. Color Property: Computed property backed by TARDISManager state
     * 
     * The didSet handlers implement context-aware behavior:
     * - Master Power Switch Context: Triggers smooth fade effects
     * - Direct User Control: Provides immediate response
     * - Power-off Protection: Prevents interference during global fade-out
     * 
     * This dual-mode behavior creates an intuitive user experience where
     * the master power switch creates dramatic lighting effects, while
     * individual controls provide precise, immediate feedback.
     */

    // MARK: - Top Light Section
    /**
     * Controls the beacon light at the top of the TARDIS.
     * This is typically the most prominent light element and often
     * represents the "power status" of the time machine.
     */
    var topLightOnOff: Bool = false {
        didSet {
            if topLightOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .topLight, color: .white, duration: 1.0)
                    TARDISManager.shared.setColorStateForFade(for: .topLight, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .topLight)
                    topLightColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .topLight)
                }
            }
        }
    }
    /**
     * topLightColor: Computed property providing real-time color control.
     * 
     * Get: Retrieves current color from TARDISManager's central state
     * Set: Triggers immediate hardware update via TARDISManager
     * 
     * This pattern ensures the UI always reflects actual hardware state
     * while providing seamless color updates during user interaction.
     */
    var topLightColor: Color {
        get { TARDISManager.shared.sectionColors[.topLight] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .topLight, color: newValue) }
    }

    // MARK: - Window Lighting Sections
    /**
     * The four window sections provide ambient lighting around the TARDIS.
     * These lights create the characteristic glow effect and can be controlled
     * individually for complex lighting scenes or synchronized for dramatic effects.
     */

    // Front Window Section
    var frontWindowOnOff: Bool = false {
        didSet {
            if frontWindowOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .frontWindow, color: .white, duration: 1.0)
                    // Update UI state without triggering API call - the fade handles the hardware
                    TARDISManager.shared.setColorStateForFade(for: .frontWindow, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .frontWindow)
                    frontWindowColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .frontWindow)
                }
            }
        }
    }
    var frontWindowColor: Color {
        get { TARDISManager.shared.sectionColors[.frontWindow] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .frontWindow, color: newValue) }
    }
    
    // Left Window Section
    var leftWindowOnOff: Bool = false {
        didSet {
            if leftWindowOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .leftWindow, color: .white, duration: 1.0)
                    // Update UI state without triggering API call - the fade handles the hardware
                    TARDISManager.shared.setColorStateForFade(for: .leftWindow, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .leftWindow)
                    leftWindowColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .leftWindow)
                }
            }
        }
    }
    var leftWindowColor: Color {
        get { TARDISManager.shared.sectionColors[.leftWindow] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .leftWindow, color: newValue) }
    }
    
    // Right Window Section  
    var rightWindowOnOff: Bool = false {
        didSet {
            if rightWindowOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .rightWindow, color: .white, duration: 1.0)
                    // Update UI state without triggering API call - the fade handles the hardware
                    TARDISManager.shared.setColorStateForFade(for: .rightWindow, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .rightWindow)
                    rightWindowColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .rightWindow)
                }
            }
        }
    }
    var rightWindowColor: Color {
        get { TARDISManager.shared.sectionColors[.rightWindow] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .rightWindow, color: newValue) }
    }
    
    // Rear Window Section
    var rearWindowOnOff: Bool = false {
        didSet {
            if rearWindowOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .rearWindow, color: .white, duration: 1.0)
                    // Update UI state without triggering API call - the fade handles the hardware
                    TARDISManager.shared.setColorStateForFade(for: .rearWindow, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .rearWindow)
                    rearWindowColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .rearWindow)
                }
            }
        }
    }
    var rearWindowColor: Color {
        get { TARDISManager.shared.sectionColors[.rearWindow] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .rearWindow, color: newValue) }
    }
      
    // MARK: - Police Sign Lighting Sections
    /**
     * The four police sign lights illuminate the "POLICE BOX" signage on each side.
     * These lights are essential for the authentic TARDIS appearance and provide
     * accent lighting that can be used for status indication or dramatic effects.
     */

    // Front Police Sign Section
    var frontPoliceSignOnOff: Bool = false {
        didSet {
            if frontPoliceSignOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .frontPoliceSign, color: .white, duration: 1.0)
                    // Update UI state without triggering API call - the fade handles the hardware
                    TARDISManager.shared.setColorStateForFade(for: .frontPoliceSign, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .frontPoliceSign)
                    frontPoliceSignColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .frontPoliceSign)
                }
            }
        }
    }
    var frontPoliceSignColor: Color {
        get { TARDISManager.shared.sectionColors[.frontPoliceSign] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .frontPoliceSign, color: newValue) }
    }
    
    // Left Police Sign Section
    var leftPoliceSignOnOff: Bool = false {
        didSet {
            if leftPoliceSignOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .leftPoliceSign, color: .white, duration: 1.0)
                    // Update UI state without triggering API call - the fade handles the hardware
                    TARDISManager.shared.setColorStateForFade(for: .leftPoliceSign, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .leftPoliceSign)
                    leftPoliceSignColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .leftPoliceSign)
                }
            }
        }
    }
    var leftPoliceSignColor: Color {
        get { TARDISManager.shared.sectionColors[.leftPoliceSign] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .leftPoliceSign, color: newValue) }
    }
    
    // Rear Police Sign Section
    var rearPoliceSignOnOff: Bool = false {
        didSet {
            if rearPoliceSignOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .rearPoliceSign, color: .white, duration: 1.0)
                    // Update UI state without triggering API call - the fade handles the hardware
                    TARDISManager.shared.setColorStateForFade(for: .rearPoliceSign, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .rearPoliceSign)
                    rearPoliceSignColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .rearPoliceSign)
                }
            }
        }
    }
    var rearPoliceSignColor: Color {
        get { TARDISManager.shared.sectionColors[.rearPoliceSign] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .rearPoliceSign, color: newValue) }
    }
    
    // Right Police Sign Section
    var rightPoliceSignOnOff: Bool = false {
        didSet {
            if rightPoliceSignOnOff {
                if isUpdatingFromPowerSwitch {
                    // Fade in when controlled by main power switch
                    TARDISManager.shared.fadeLED(section: .rightPoliceSign, color: .white, duration: 1.0)
                    // Update UI state without triggering API call - the fade handles the hardware
                    TARDISManager.shared.setColorStateForFade(for: .rightPoliceSign, color: .white)
                } else {
                    // Immediate turn on when controlled directly
                    TARDISManager.shared.turnOn(section: .rightPoliceSign)
                    rightPoliceSignColor = .white
                }
            } else {
                // Only turn off immediately if this is a direct user action, not from the main power switch
                if !isUpdatingFromPowerSwitch {
                    TARDISManager.shared.turnOff(section: .rightPoliceSign)
                }
            }
        }
    }
    var rightPoliceSignColor: Color {
        get { TARDISManager.shared.sectionColors[.rightPoliceSign] ?? .black }
        set { TARDISManager.shared.setLightColor(for: .rightPoliceSign, color: newValue) }
    }
    
    // MARK: - Testing and Development
    /**
     * runTest: Development function for testing hardware connectivity and lighting effects.
     * This function delegates to TARDISManager's test routine, which typically:
     * - Cycles through different colors on all sections
     * - Verifies hardware communication
     * - Demonstrates the full range of lighting capabilities
     * 
     * Useful for:
     * - Hardware debugging
     * - Demonstrating lighting capabilities
     * - Verifying network connectivity to TARDIS hardware
     */
    func runTest() async {
        await TARDISManager.shared.runTest()
    }
}
